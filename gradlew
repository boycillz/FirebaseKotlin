/*
 * Copyright (C) 2007 The Android Open Source Project
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package org.apache.harmony.xml;

import dalvik.annotation.optimization.ReachabilitySensitive;
import java.io.IOException;
import java.io.InputStream;
import java.io.Reader;
import java.net.URI;
import java.net.URL;
import java.net.URLConnection;
import libcore.io.IoUtils;
import org.xml.sax.Attributes;
import org.xml.sax.ContentHandler;
import org.xml.sax.DTDHandler;
import org.xml.sax.EntityResolver;
import org.xml.sax.InputSource;
import org.xml.sax.Locator;
import org.xml.sax.SAXException;
import org.xml.sax.SAXParseException;
import org.xml.sax.ext.LexicalHandler;

/**
 * Adapts SAX API to the Expat native XML parser. Not intended for reuse
 * across documents.
 *
 * @see org.apache.harmony.xml.ExpatReader
 */
class ExpatParser {

    private static final int BUFFER_SIZE = 8096; // in bytes

    /** Pointer to XML_Parser instance. */
    // A few native methods taking the pointer value are static; @ReachabilitySensitive is
    // necessary to ensure the Java object is kept reachable sufficiently long in these cases.
    @ReachabilitySensitive
    private long pointer;

    private boolean inStartElement = false;
    private int attributeCount = -1;
    private long attributePointer = 0;

    private final Locator locator = new ExpatLocator();

    private final ExpatReader xmlReader;

    private final String publicId;
    private final String systemId;

    private final String encoding;

    private final ExpatAttributes attributes = new CurrentAttributes();

    private static final String OUTSIDE_START_ELEMENT
            = "Attributes can only be used within the scope of startElement().";

    /** We default to UTF-8 when the user doesn't specify an encoding. */
    private static final String DEFAULT_ENCODING = "UTF-8";

    /** Encoding used for Java chars, used to parse Readers and Strings */
    /*package*/ static final String CHARACTER_ENCODING = "UTF-16";

    /** Timeout for HTTP connections (in ms) */
    private static final int TIMEOUT = 20 * 1000;

    /**
     * Constructs a new parser with the specified encoding.
     */
    /*package*/ ExpatParser(String encoding, ExpatReader xmlReader,
            boolean processNamespaces, String publicId, String systemId) {
        this.publicId = publicId;
        this.systemId = systemId;

        this.xmlReader = xmlReader;

        /*
         * TODO: Let Expat try to guess the encoding instead of defaulting.
         * Unfortunately, I don't know how to tell which encoding Expat picked,
         * so I won't know how to encode "<externalEntity>" below. The solution
         * I think is to fix Expat to not require the "<externalEntity>"
         * workaround.
         */
        this.encoding = encoding == null ? DEFAULT_ENCODING : encoding;
        this.pointer = initialize(
            this.encoding,
            processNamespaces
        );
    }

    /**
     * Used by {@link EntityParser}.
     */
    private ExpatParser(String encoding, ExpatReader xmlReader, long pointer,
            String publicId, String systemId) {
        this.encoding = encoding;
        this.xmlReader = xmlReader;
        this.pointer = pointer;
        this.systemId = systemId;
        this.publicId = publicId;
    }

    /**
     * Initializes native resources.
     *
     * @return the pointer to the native parser
     */
    private native long initialize(String encoding, boolean namespacesEnabled);

    /**
     * Called at the start of an element.
     *
     * @param uri namespace URI of element or "" if namespace processing is
     *  disabled
     * @param localName local name of element or "" if namespace processing is
     *  disabled
     * @param qName qualified name or "" if namespace processing is enabled
     * @param attributePointer pointer to native attribute char*--we keep
     *  a separate pointer so we can detach it from the parser instance
     * @param attributeCount number of attributes
     */
    /*package*/ void startElement(String uri, String localName, String qName,
            long attributePointer, int attributeCount) throws SAXException {
        ContentHandler contentHandler = xmlReader.contentHandler;
        if (contentHandler == null) {
            return;
        }

        try {
            inStartElement = true;
            this.attributePointer = attributePointer;
            this.attributeCount = attributeCount;

            contentHandler.startElement(
                    uri, localName, qName, this.attributes);
        } finally {
            inStartElement = false;
            this.attributeCount = -1;
            this.attributePointer = 0;
        }
    }

    /*package*/ void endElement(String uri,
 setFileDescriptorsForSend(FileDescriptor[] fds) {
        impl.setFileDescriptorsForSend(fds);
    }

    /**
     * Retrieves a set of file descriptors that a peer has sent through
     * an ancillary message. This method retrieves the most recent set sent,
     * and then returns null until a new set arrives.
     * File descriptors may only be passed along with regular data, so this
     * method can only return a non-null after a read operation.
     *
     * @return null or file descriptor array
     * @throws IOException
     */
    public FileDescriptor[] getAncillaryFileDescriptors() throws IOException {
        return impl.getAncillaryFileDescriptors();
    }

    /**
     * Retrieves the cr
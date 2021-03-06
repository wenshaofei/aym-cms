package de.zib.scalaris.examples.wikipedia;

import de.zib.scalaris.examples.wikipedia.data.Page;
import de.zib.scalaris.examples.wikipedia.data.Revision;

/**
 * Result of an operation getting a revision.
 * 
 * @author Nico Kruber, kruber@zib.de
 */
public class RevisionResult extends Result {
    /**
     * Revision on success.
     */
    public Revision revision = null;
    /**
     * Page on success (if retrieved).
     */
    public Page page = null;
    /**
     * Whether the pages exists or not.
     */
    public boolean page_not_existing = false;
    /**
     * Whether the requested revision exists or not.
     */
    public boolean rev_not_existing = false;
    
    /**
     * Creates a new successful result with the given revision.
     *
     * @param page      the retrieved page 
     * @param revision  the retrieved revision
     * @param time      time in milliseconds for this operation
     */
    public RevisionResult(Page page, Revision revision, long time) {
        super(time);
        this.page = page;
        this.revision = revision;
    }
    /**
     * Creates a new custom result.
     * 
     * @param success            the success status
     * @param message            the message to use
     * @param connectFailed      whether the connection to the DB failed or not
     * @param page               page on success (if retrieved)
     * @param revision           revision on success
     * @param page_not_existing  whether the pages exists or not
     * @param rev_not_existing   whether the requested revision exists or not
     * @param time               time in milliseconds for this operation
     */
    public RevisionResult(boolean success, String message,
            boolean connectFailed, Page page, Revision revision,
            boolean page_not_existing, boolean rev_not_existing, long time) {
        super(success, message, connectFailed, time);
        this.page = page;
        this.revision = revision;
        this.page_not_existing = page_not_existing;
        this.rev_not_existing = rev_not_existing;
    }
}
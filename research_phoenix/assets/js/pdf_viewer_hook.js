import { PDFViewer } from './pdf_viewer';

export const PDFViewerHook = {
  mounted() {
    console.log('PDFViewerHook mounted');
    this.initViewer();
  },

  reconnected() {
    console.log('PDFViewerHook reconnected');
    // Re-initialize the viewer after reconnection
    this.initViewer();
  },

  initViewer() {
    const pdfUrl = this.el.dataset.pdfUrl;
    const paperId = this.el.dataset.paperId;
    
    console.log('PDF URL:', pdfUrl);
    console.log('Paper ID:', paperId);
    
    if (!pdfUrl) {
      console.error('No PDF URL provided');
      return;
    }

    // Clean up existing viewer if it exists
    if (this.pdfViewer) {
      this.pdfViewer.destroy();
    }

    // Wait for PDF.js to be available with retry logic
    this.waitForPDFLib().then(() => {
      this.pdfViewer = new PDFViewer(this.el, pdfUrl, {
        scale: 1.2,
        onNoteClick: (note) => {
          this.pushEvent('note_clicked', { noteId: note.id });
        },
        onPageClick: (position) => {
          this.pushEvent('page_clicked', { 
            page: position.page,
            x: position.x,
            y: position.y
          });
        }
      });

      this.setupEventHandlers();
    }).catch(error => {
      console.error('Failed to initialize PDF viewer:', error);
      this.el.innerHTML = '<div class="error p-4 text-red-600 border border-red-300 rounded">Failed to load PDF viewer. Please refresh the page.</div>';
    });
  },

  waitForPDFLib(maxRetries = 10, delay = 500) {
    return new Promise((resolve, reject) => {
      let retries = 0;
      
      const check = () => {
        if (window.pdfjsLib) {
          resolve();
        } else if (retries < maxRetries) {
          retries++;
          console.log(`Waiting for PDF.js library... attempt ${retries}/${maxRetries}`);
          setTimeout(check, delay);
        } else {
          reject(new Error('PDF.js library not loaded after maximum retries'));
        }
      };
      
      check();
    });
  },

  setupEventHandlers() {
    this.handleEvent('load_notes', (notes) => {
      if (this.pdfViewer) {
        notes.forEach(note => {
          this.pdfViewer.addNote({
            id: note.id,
            page: note.page || 1,
            x: note.x || 50,
            y: note.y || 50,
            content: note.content
          });
        });
      }
    });

    this.handleEvent('add_note', (note) => {
      if (this.pdfViewer) {
        this.pdfViewer.addNote({
          id: note.id,
          page: note.page || 1,
          x: note.x || 50,
          y: note.y || 50,
          content: note.content
        });
      }
    });

    this.handleEvent('remove_note', ({ noteId }) => {
      if (this.pdfViewer) {
        this.pdfViewer.removeNote(noteId);
      }
    });

    this.handleEvent('go_to_page', ({ page }) => {
      if (this.pdfViewer) {
        this.pdfViewer.goToPage(page);
      }
    });
  },

  destroyed() {
    if (this.pdfViewer) {
      this.pdfViewer.destroy();
      this.pdfViewer = null;
    }
  }
};
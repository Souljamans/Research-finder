import { PDFViewer } from './pdf_viewer';

export const PDFViewerHook = {
  mounted() {
    console.log('=== PDFViewerHook mounted ===');
    console.log('Element:', this.el);
    console.log('Dataset:', this.el.dataset);
    this.initViewer();
  },

  reconnected() {
    console.log('=== PDFViewerHook reconnected ===');
    // Re-initialize the viewer after reconnection
    this.initViewer();
  },

  updated() {
    console.log('=== PDFViewerHook updated ===');
    console.log('Element:', this.el);
    console.log('Current PDF viewer:', !!this.pdfViewer);
    console.log('PDF viewer state:', {
      currentPage: this.pdfViewer?.currentPage,
      scale: this.pdfViewer?.scale,
      pdfLoaded: !!this.pdfViewer?.pdf
    });

    // Always check if we need to restore the PDF viewer after LiveView updates
    const canvas = this.el.querySelector('#pdfCanvas');
    const controls = this.el.querySelector('.pdf-controls');

    if (!canvas || !controls) {
      console.log('PDF viewer DOM elements missing, re-initializing...');
      this.initViewer();
    } else if (this.pdfViewer && this.pdfViewer.pdf) {
      // PDF viewer exists but canvas might be corrupted, check if it's working
      const context = canvas.getContext('2d');
      if (!context || canvas.width === 0 || canvas.height === 0) {
        console.log('PDF canvas corrupted, re-rendering current page...');
        this.pdfViewer.renderPage(this.pdfViewer.currentPage);
      }
    }
  },

  initViewer() {
    const pdfUrl = this.el.dataset.pdfUrl;
    const paperId = this.el.dataset.paperId;

    console.log('=== Initializing PDF Viewer ===');
    console.log('PDF URL:', pdfUrl);
    console.log('Paper ID:', paperId);
    console.log('Element ID:', this.el.id);
    console.log('Element classes:', this.el.className);
    console.log('Existing PDF viewer:', !!this.pdfViewer);
    console.log('Canvas exists:', !!this.el.querySelector('#pdfCanvas'));

    if (!pdfUrl) {
      console.error('No PDF URL provided in dataset');
      this.el.innerHTML = '<div class="error p-4 text-red-600 border border-red-300 rounded">No PDF URL provided</div>';
      return;
    }

    // Don't re-initialize if PDF viewer is already working and canvas exists
    if (this.pdfViewer && this.el.querySelector('#pdfCanvas') && this.pdfViewer.pdf) {
      console.log('PDF viewer already initialized and working, skipping re-initialization');
      return;
    }

    // Clean up existing viewer if it exists
    if (this.pdfViewer) {
      console.log('Cleaning up existing PDF viewer');
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
          console.log('=== PDF Canvas Clicked ===');
          console.log('Position data:', position);

          // Don't send to server immediately - handle locally first
          this.showNoteForm(position);
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
    this.handleEvent('load_notes', (data) => {
      if (this.pdfViewer) {
        const notes = data.notes || data;  // Handle both {notes: [...]} and [...] formats
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

  showNoteForm(position) {
    console.log('=== Showing Note Form ===');
    console.log('Position:', position);

    // Remove any existing note form
    this.hideNoteForm();

    // Create note form overlay
    const noteForm = document.createElement('div');
    noteForm.id = 'note-form-overlay';
    noteForm.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
    noteForm.innerHTML = `
      <div class="bg-white p-6 rounded-lg shadow-lg max-w-md w-full mx-4">
        <h3 class="text-lg font-semibold mb-4 text-black">Add Note</h3>
        <div class="mb-4">
          <label class="block text-sm font-medium mb-2 text-black">Note Content</label>
          <textarea id="note-content" class="w-full p-3 border border-gray-300 rounded-lg text-black" rows="4" placeholder="Enter your note..."></textarea>
        </div>
        <div class="mb-4">
          <label class="block text-sm font-medium mb-2 text-black">Note Type</label>
          <select id="note-type" class="w-full p-3 border border-gray-300 rounded-lg text-black">
            <option value="text">Text Note</option>
            <option value="highlight">Highlight</option>
            <option value="annotation">Annotation</option>
          </select>
        </div>
        <div class="flex space-x-3">
          <button id="save-note" class="flex-1 bg-blue-500 text-white px-4 py-2 rounded-lg hover:bg-blue-600">Add Note</button>
          <button id="cancel-note" class="flex-1 bg-gray-500 text-white px-4 py-2 rounded-lg hover:bg-gray-600">Cancel</button>
        </div>
      </div>
    `;

    document.body.appendChild(noteForm);

    // Store position for later use
    this.selectedPosition = position;

    // Add event listeners
    noteForm.querySelector('#save-note').addEventListener('click', () => {
      this.saveNote();
    });

    noteForm.querySelector('#cancel-note').addEventListener('click', () => {
      this.hideNoteForm();
    });

    // Close on overlay click
    noteForm.addEventListener('click', (e) => {
      if (e.target === noteForm) {
        this.hideNoteForm();
      }
    });

    // Focus on textarea
    noteForm.querySelector('#note-content').focus();
  },

  hideNoteForm() {
    const existingForm = document.getElementById('note-form-overlay');
    if (existingForm) {
      existingForm.remove();
    }
    this.selectedPosition = null;
  },

  saveNote() {
    const content = document.getElementById('note-content').value.trim();
    const noteType = document.getElementById('note-type').value;

    if (!content) {
      alert('Please enter note content');
      return;
    }

    if (!this.selectedPosition) {
      alert('No position selected');
      return;
    }

    console.log('=== Saving Note ===');
    console.log('Content:', content);
    console.log('Type:', noteType);
    console.log('Position:', this.selectedPosition);

    // Send note data to server
    this.pushEvent('create_note', {
      content: content,
      note_type: noteType,
      page: this.selectedPosition.page,
      x: this.selectedPosition.x,
      y: this.selectedPosition.y
    });

    this.hideNoteForm();
  },

  destroyed() {
    this.hideNoteForm();
    if (this.pdfViewer) {
      this.pdfViewer.destroy();
      this.pdfViewer = null;
    }
  }
};
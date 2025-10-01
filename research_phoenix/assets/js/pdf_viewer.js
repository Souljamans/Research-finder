// Use PDF.js via CDN for better compatibility
const pdfjsLib = window.pdfjsLib;

export class PDFViewer {
  constructor(container, pdfUrl, options = {}) {
    this.container = container;
    this.pdfUrl = pdfUrl;
    this.pdf = null;
    this.currentPage = 1;
    this.scale = options.scale || 1.2;
    this.notes = new Map();
    this.onNoteClick = options.onNoteClick || (() => {});
    this.onPageClick = options.onPageClick || (() => {});
    
    this.init();
  }

  async init() {
    console.log('=== PDF Viewer Initialization ===');
    console.log('PDF URL:', this.pdfUrl);
    console.log('Container:', this.container);
    console.log('pdfjsLib available:', !!window.pdfjsLib);
    console.log('pdfjsLib version:', window.pdfjsLib?.version);
    console.log('Worker source:', window.pdfjsLib?.GlobalWorkerOptions?.workerSrc);

    if (!window.pdfjsLib) {
      console.error('PDF.js not loaded');
      this.container.innerHTML = '<div class="error p-4 text-red-600 border border-red-300 rounded">PDF.js library not loaded. Please refresh the page.</div>';
      return;
    }

    try {
      console.log('Loading PDF document...');

      // Set up loading indicator
      this.container.innerHTML = '<div class="flex items-center justify-center p-8"><div class="loading loading-spinner loading-lg"></div><span class="ml-4">Loading PDF...</span></div>';

      // First try to fetch the PDF with credentials to check if it's accessible
      console.log('Testing PDF URL accessibility...');
      const testResponse = await fetch(this.pdfUrl, {
        method: 'HEAD',
        credentials: 'same-origin',
        headers: {
          'X-Requested-With': 'XMLHttpRequest'
        }
      });

      if (!testResponse.ok) {
        throw new Error(`HTTP ${testResponse.status}: ${testResponse.statusText}`);
      }

      console.log('PDF URL accessible, loading with PDF.js...');

      // Try loading with PDF.js
      const loadingTask = pdfjsLib.getDocument({
        url: this.pdfUrl,
        withCredentials: true
      });
      const timeoutPromise = new Promise((_, reject) =>
        setTimeout(() => reject(new Error('PDF loading timeout')), 30000)
      );

      this.pdf = await Promise.race([loadingTask.promise, timeoutPromise]);
      console.log('PDF loaded successfully, pages:', this.pdf.numPages);
      this.setupControls();
      this.renderPage(1);
    } catch (error) {
      console.error('Error loading PDF:', error);
      let errorMessage = 'Error loading PDF';

      if (error.message.includes('timeout')) {
        errorMessage = 'PDF loading timed out. Please try refreshing the page.';
      } else if (error.message.includes('Invalid PDF')) {
        errorMessage = 'Invalid PDF file. Please check the file format.';
      } else if (error.message.includes('NetworkError') || error.message.includes('HTTP')) {
        errorMessage = `Network error loading PDF: ${error.message}. This might be an authentication issue.`;
      } else {
        errorMessage = `Error loading PDF: ${error.message}`;
      }

      this.container.innerHTML = `
        <div class="error p-4 text-red-600 border border-red-300 rounded bg-red-50">
          <h3 class="font-semibold mb-2">PDF Loading Error</h3>
          <p>${errorMessage}</p>
          <p class="text-sm mt-2 text-gray-600">PDF URL: ${this.pdfUrl}</p>
          <button onclick="window.location.reload()" class="mt-3 px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700">
            Refresh Page
          </button>
        </div>
      `;
    }
  }

  setupControls() {
    const controlsHtml = `
      <div class="pdf-controls bg-gray-100 p-2 flex items-center justify-between border-b">
        <div class="flex items-center space-x-2">
          <button id="prevPage" class="px-3 py-1 bg-blue-500 text-white rounded disabled:bg-gray-300">Previous</button>
          <span>Page <span id="currentPage">1</span> of <span id="totalPages">${this.pdf.numPages}</span></span>
          <button id="nextPage" class="px-3 py-1 bg-blue-500 text-white rounded disabled:bg-gray-300">Next</button>
        </div>
        <div class="flex items-center space-x-2">
          <button id="zoomOut" class="px-3 py-1 bg-gray-500 text-white rounded">-</button>
          <span id="zoomLevel">${Math.round(this.scale * 100)}%</span>
          <button id="zoomIn" class="px-3 py-1 bg-gray-500 text-white rounded">+</button>
        </div>
      </div>
      <div class="pdf-viewer-content relative overflow-auto" style="height: calc(100vh - 200px);">
        <canvas id="pdfCanvas" class="border shadow-lg"></canvas>
        <div id="noteOverlay" class="absolute top-0 left-0 pointer-events-none"></div>
      </div>
    `;
    
    this.container.innerHTML = controlsHtml;
    this.bindEvents();
  }

  bindEvents() {
    document.getElementById('prevPage').addEventListener('click', () => {
      if (this.currentPage > 1) {
        this.renderPage(--this.currentPage);
      }
    });

    document.getElementById('nextPage').addEventListener('click', () => {
      if (this.currentPage < this.pdf.numPages) {
        this.renderPage(++this.currentPage);
      }
    });

    document.getElementById('zoomIn').addEventListener('click', () => {
      this.scale = Math.min(this.scale * 1.2, 3.0);
      this.renderPage(this.currentPage);
    });

    document.getElementById('zoomOut').addEventListener('click', () => {
      this.scale = Math.max(this.scale / 1.2, 0.3);
      this.renderPage(this.currentPage);
    });

    const canvas = document.getElementById('pdfCanvas');
    canvas.addEventListener('click', (e) => {
      console.log('=== PDF Canvas Clicked ===');
      const rect = canvas.getBoundingClientRect();
      const x = e.clientX - rect.left;
      const y = e.clientY - rect.top;
      const pageX = (x / canvas.offsetWidth) * 100;
      const pageY = (y / canvas.offsetHeight) * 100;

      console.log('Click position:', { x, y, pageX, pageY, currentPage: this.currentPage });
      console.log('onPageClick function:', typeof this.onPageClick);

      this.onPageClick({
        page: this.currentPage,
        x: pageX,
        y: pageY,
        canvasX: x,
        canvasY: y
      });
    });
  }

  async renderPage(pageNum) {
    console.log('=== Rendering Page ===');
    console.log('Page number:', pageNum);
    console.log('Current scale:', this.scale);

    try {
      const page = await this.pdf.getPage(pageNum);
      const viewport = page.getViewport({ scale: this.scale });

      console.log('Viewport:', viewport);

      const canvas = document.getElementById('pdfCanvas');
      if (!canvas) {
        console.error('Canvas element not found!');
        return;
      }

      const context = canvas.getContext('2d');
      if (!context) {
        console.error('Could not get canvas context!');
        return;
      }

      console.log('Setting canvas dimensions:', viewport.width, 'x', viewport.height);
      canvas.height = viewport.height;
      canvas.width = viewport.width;

      const renderContext = {
        canvasContext: context,
        viewport: viewport
      };

      console.log('Starting page render...');
      await page.render(renderContext).promise;
      console.log('Page render completed successfully');

      this.updateControls();
      this.renderNotes();
    } catch (error) {
      console.error('Error rendering page:', error);
      this.container.innerHTML = `<div class="error p-4 text-red-600 border border-red-300 rounded">Error rendering PDF page: ${error.message}</div>`;
    }
  }

  updateControls() {
    document.getElementById('currentPage').textContent = this.currentPage;
    document.getElementById('zoomLevel').textContent = `${Math.round(this.scale * 100)}%`;
    
    document.getElementById('prevPage').disabled = this.currentPage === 1;
    document.getElementById('nextPage').disabled = this.currentPage === this.pdf.numPages;
  }

  addNote(note) {
    if (!this.notes.has(note.page)) {
      this.notes.set(note.page, []);
    }
    this.notes.get(note.page).push(note);
    
    if (note.page === this.currentPage) {
      this.renderNotes();
    }
  }

  removeNote(noteId) {
    for (let [page, notes] of this.notes.entries()) {
      const index = notes.findIndex(note => note.id === noteId);
      if (index !== -1) {
        notes.splice(index, 1);
        if (page === this.currentPage) {
          this.renderNotes();
        }
        break;
      }
    }
  }

  renderNotes() {
    const overlay = document.getElementById('noteOverlay');
    const canvas = document.getElementById('pdfCanvas');
    
    if (!overlay || !canvas) return;
    
    overlay.innerHTML = '';
    overlay.style.width = canvas.offsetWidth + 'px';
    overlay.style.height = canvas.offsetHeight + 'px';
    
    const pageNotes = this.notes.get(this.currentPage) || [];
    
    pageNotes.forEach(note => {
      const noteElement = document.createElement('div');
      noteElement.className = 'note-marker absolute bg-yellow-400 border-2 border-yellow-600 rounded-full cursor-pointer pointer-events-auto';
      noteElement.style.width = '20px';
      noteElement.style.height = '20px';
      noteElement.style.left = `${(note.x / 100) * canvas.offsetWidth - 10}px`;
      noteElement.style.top = `${(note.y / 100) * canvas.offsetHeight - 10}px`;
      noteElement.title = note.content;
      noteElement.dataset.noteId = note.id;
      
      noteElement.addEventListener('click', (e) => {
        e.stopPropagation();
        this.onNoteClick(note);
      });
      
      overlay.appendChild(noteElement);
    });
  }

  goToPage(pageNum) {
    if (pageNum >= 1 && pageNum <= this.pdf.numPages) {
      this.currentPage = pageNum;
      this.renderPage(pageNum);
    }
  }

  destroy() {
    // Clean up any event listeners or resources
    if (this.pdf) {
      this.pdf = null;
    }
    if (this.container) {
      this.container.innerHTML = '';
    }
    this.notes.clear();
  }
}
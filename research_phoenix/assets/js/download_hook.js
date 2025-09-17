export const DownloadHook = {
  mounted() {
    this.handleEvent("download_file", ({ content, filename, content_type }) => {
      const blob = new Blob([content], { type: content_type });
      const url = window.URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = filename;
      link.style.display = 'none';
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      window.URL.revokeObjectURL(url);
    });
  }
};
import fs from 'fs/promises';
import { getFilePath } from '../config/storage.js';

// Dynamic import to avoid debug mode issues
const importPdfParse = async () => {
  const { default: pdfParse } = await import('pdf-parse');
  return pdfParse;
};

export class PDFService {
  static async extractTextFromFile(filename) {
    try {
      const filePath = getFilePath(filename);
      const fileBuffer = await fs.readFile(filePath);
      
      const pdfParse = await importPdfParse();
      const data = await pdfParse(fileBuffer);
      
      return {
        text: data.text,
        numPages: data.numpages,
        info: data.info,
        metadata: data.metadata,
        version: data.version
      };
    } catch (error) {
      console.error('PDF text extraction error:', error);
      throw new Error(`Failed to extract text from PDF: ${error.message}`);
    }
  }

  static async extractMetadataFromFile(filename) {
    try {
      const filePath = getFilePath(filename);
      const fileBuffer = await fs.readFile(filePath);
      
      const pdfParse = await importPdfParse();
      const data = await pdfParse(fileBuffer);
      
      const extractedMetadata = {
        title: data.info?.Title || null,
        author: data.info?.Author || null,
        subject: data.info?.Subject || null,
        creator: data.info?.Creator || null,
        producer: data.info?.Producer || null,
        creationDate: data.info?.CreationDate || null,
        modificationDate: data.info?.ModDate || null,
        numPages: data.numpages,
        pdfVersion: data.version
      };

      return extractedMetadata;
    } catch (error) {
      console.error('PDF metadata extraction error:', error);
      throw new Error(`Failed to extract metadata from PDF: ${error.message}`);
    }
  }

  static async processUploadedPDF(filename) {
    try {
      const [textData, metadata] = await Promise.all([
        this.extractTextFromFile(filename),
        this.extractMetadataFromFile(filename)
      ]);

      return {
        extractedText: textData.text,
        metadata: {
          ...metadata,
          wordCount: this.estimateWordCount(textData.text),
          extractedTitle: this.extractTitleFromText(textData.text),
          extractedAuthors: this.extractAuthorsFromText(textData.text)
        }
      };
    } catch (error) {
      console.error('PDF processing error:', error);
      throw new Error(`Failed to process PDF: ${error.message}`);
    }
  }

  static estimateWordCount(text) {
    if (!text) return 0;
    return text.trim().split(/\s+/).filter(word => word.length > 0).length;
  }

  static extractTitleFromText(text) {
    if (!text) return null;
    
    const lines = text.split('\n').filter(line => line.trim().length > 0);
    
    for (const line of lines.slice(0, 10)) {
      const cleanLine = line.trim();
      if (cleanLine.length > 10 && cleanLine.length < 200) {
        if (!cleanLine.toLowerCase().includes('abstract') &&
            !cleanLine.toLowerCase().includes('introduction') &&
            !cleanLine.toLowerCase().match(/^\d+\.?\s/) &&
            !cleanLine.match(/^[A-Z\s]{10,}$/)) {
          return cleanLine;
        }
      }
    }
    
    return null;
  }

  static extractAuthorsFromText(text) {
    if (!text) return [];
    
    const lines = text.split('\n').slice(0, 20);
    const authors = [];
    
    const authorPatterns = [
      /^([A-Z][a-z]+ [A-Z][a-z]+(?:,? (?:and |& )?[A-Z][a-z]+ [A-Z][a-z]+)*)/,
      /^([A-Z]\. [A-Z][a-z]+(?:,? (?:and |& )?[A-Z]\. [A-Z][a-z]+)*)/,
      /By:?\s+([A-Z][a-z]+ [A-Z][a-z]+(?:,? (?:and |& )?[A-Z][a-z]+ [A-Z][a-z]+)*)/i
    ];
    
    for (const line of lines) {
      const cleanLine = line.trim();
      
      for (const pattern of authorPatterns) {
        const match = cleanLine.match(pattern);
        if (match) {
          const authorString = match[1];
          const extractedAuthors = authorString
            .split(/,|\band\b|\&/)
            .map(author => author.trim())
            .filter(author => author.length > 3 && /^[A-Z]/.test(author));
          
          if (extractedAuthors.length > 0) {
            return extractedAuthors.slice(0, 10);
          }
        }
      }
    }
    
    return authors;
  }
}
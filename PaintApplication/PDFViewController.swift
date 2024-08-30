//
//  PDFViewController.swift
//  PaintApplication
//
//  Created by EBRU KÖSE on 28.08.2024.
//

import Foundation
import UIKit
import PDFKit
import PencilKit

class PDFViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver {
    
    var pdfView: PDFView!
    var canvasView: PKCanvasView!
    var toolPicker: PKToolPicker!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupPDFView()
        setupCanvasView()
        setupToolPicker()
    }
    
    private func setupPDFView() {
        pdfView = PDFView(frame: view.bounds)
        pdfView.autoScales = true
        view.addSubview(pdfView)
    }
    
    private func setupCanvasView() {
        canvasView = PKCanvasView(frame: view.bounds)
        canvasView.delegate = self
        canvasView.drawingPolicy = .anyInput
        view.addSubview(canvasView)
    }
    
    private func setupToolPicker() {
        toolPicker = PKToolPicker()
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        toolPicker.addObserver(canvasView)
        canvasView.becomeFirstResponder()
    }
    
    @objc func loadPDF() {
        let documentPicker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf], asCopy: true)
        documentPicker.delegate = self
        present(documentPicker, animated: true, completion: nil)
    }
    
    @objc func savePDF() {
        guard let document = pdfView.document else { return }
        
        let pdfPage = document.page(at: 0)!
        let bounds = pdfPage.bounds(for: .mediaBox)
        
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        let img = renderer.image { ctx in
            // PDF içeriğini çiz
            pdfPage.draw(with: .mediaBox, to: ctx.cgContext)
            // PKCanvasView çizimlerini üstüne ekle
            canvasView.drawing.image(from: bounds, scale: 1.0).draw(in: bounds)
        }
        
        let pdfData = NSMutableData()
        UIGraphicsBeginPDFContextToData(pdfData, bounds, nil)
        UIGraphicsBeginPDFPage()
        img.draw(in: bounds)
        UIGraphicsEndPDFContext()
        
        let activityViewController = UIActivityViewController(activityItems: [pdfData], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        pdfView.frame = view.bounds
        canvasView.frame = view.bounds
    }
}

extension PDFViewController: UIDocumentPickerDelegate {
    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first else { return }
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
    }
}

//
//  ViewController.swift
//  PaintApplication
//
//  Created by EBRU KÖSE on 16.08.2024.


import UIKit
import PencilKit
import Firebase
import FirebaseFirestore


class ViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver {
    
    private let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        return canvas
    }()

    
    private var toolPicker: PKToolPicker?
    
    
    
    class PostIt: UIView, UITextFieldDelegate {
        weak var parentViewController: ViewController?

        private let textField: UITextField = {
            let textField = UITextField()
            textField.backgroundColor = .clear
            textField.textColor = .black
            textField.textAlignment = .center
            textField.font = UIFont.systemFont(ofSize: 16)
            textField.placeholder = "Type something..."
            return textField
        }()
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .systemPink
            setupPanGesture()
            setupTextField()
            setupDoneButtonAccessory()
        }
        
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }
        
        private func setupPanGesture() {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(panGesture)
            isUserInteractionEnabled = true
        }
        
        private func setupTextField() {
        
            textField.frame = bounds.insetBy(dx: 10, dy: 10)
            textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            textField.delegate = self  // UITextFieldDelegate olarak PostIt'i ayarlıyoruz
            addSubview(textField)
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(textFieldDidBeginEditing))
            textField.addGestureRecognizer(tapGesture)
           
        }
        
        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                let translation = gesture.translation(in: superview)
                center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
                gesture.setTranslation(.zero, in: superview)
            default:
                break
            }
        }
        
        // UITextFieldDelegate methodu, yazma işlemi başladığında çağrılır
       @objc func textFieldDidBeginEditing() {
            if !textField.isFirstResponder {
                textField.becomeFirstResponder()
            }
        }

        // UITextFieldDelegate methodu, yazma işlemi bittiğinde çağrılır
        @objc func textFieldDidEndEditing() {
            if let parentVC = parentViewController {
                parentVC.toolPicker?.setVisible(true, forFirstResponder: parentVC.canvasView)
                parentVC.canvasView.becomeFirstResponder()
                parentVC.canvasView.tool = parentVC.toolPicker?.selectedTool ?? PKInkingTool(.pen, color: .black, width: 5.0)

            }
        }



        
        func getText() -> String? {
            return textField.text
        }
        
        func setText(_ text: String) {
            textField.text = text
        }
        
        
        
        
        
        
        
        private func setupDoneButtonAccessory() {
                let toolbar = UIToolbar()
                toolbar.sizeToFit()
                
                let doneButton = UIBarButtonItem(title: "done", style: .done, target: self, action: #selector(doneButtonTapped))
                toolbar.setItems([doneButton], animated: false)
                
                textField.inputAccessoryView = toolbar
            }
        
        @objc private func doneButtonTapped() {
                textField.resignFirstResponder() // Klavyeyi kapatır
                textFieldDidEndEditing() // Metni işleme alır
            }
        
        
        
    }

    

    
    
    private let toolbar = UIToolbar()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CanvasView and toolPicker setup
        canvasView.delegate = self
        view.addSubview(canvasView)
        
        toolPicker = PKToolPicker()
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        toolPicker?.addObserver(self)
        canvasView.becomeFirstResponder()
        
        setupToolbar()
    }
    private var pdfViewController: PDFViewController?

  
    
    private func setupToolbar() {
        let postItButton = UIBarButtonItem(title: "Add Post-it", style: .plain, target: self, action: #selector(addPostIt))
        
               let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

               toolbar.items = [postItButton, flexibleSpace]
               toolbar.sizeToFit()
        toolbar.sizeToFit()

        view.addSubview(toolbar)
    }
    
    @objc private func addPostIt() {
        let postItView = PostIt(frame: CGRect(x: 50, y: 50, width: 200, height: 200))
        postItView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.8)
        postItView.layer.cornerRadius = 10
        postItView.layer.borderWidth = 1
        postItView.layer.borderColor = UIColor.black.cgColor
        postItView.parentViewController = self

        postItView.setText("")

        view.addSubview(postItView)

        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }
    
    
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasView.frame = view.bounds
        
        // Toolbar'ı ekranın altına yerleştirin
        toolbar.frame = CGRect(x: 0, y: view.frame.height - toolbar.frame.height, width: view.frame.width, height: toolbar.frame.height)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }
    
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        canvasView.tool = toolPicker.selectedTool
    }
    
    @IBAction func SaveItem(_ sender: Any) {
        saveDrawingToFirestore()
    }
    
    @IBAction func bringDrawing(_ sender: Any) {
        bringDrawingsFromFirestore { drawings in
            if let drawings = drawings {
                // Çizimleri PKDrawing'e dönüştür
                let pkDrawing = self.convertCustomDrawingToPKDrawing(drawings)
                
                // canvasView'ı güncelle
                self.canvasView.drawing = pkDrawing
                print("Çizim başarıyla yüklendi!")
            } else {
                print("Çizim alınamadı veya hata oluştu.")
            }
        }
    }
    
    
    
    
    
    
    
    private func bringDrawingsFromFirestore(completion: @escaping ([Drawing]?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("drawings")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting drawings: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No drawings found")
                    completion(nil)
                    return
                }
                
                do {
                    let drawings = try documents.compactMap { document -> [Drawing]? in
                        let data = document.data()
                        
                        // Veriyi "drawings" alanı altında bir dizi olarak beklediğimizden emin olalım
                        guard let drawingArray = data["drawings"] as? [[String: Any]] else {
                            print("Drawing array not found in Firestore document")
                            return nil
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: drawingArray, options: [])
                        return try JSONDecoder().decode([Drawing].self, from: jsonData)
                    }.flatMap { $0 }
                    
                    completion(drawings)
                } catch {
                    print("Error decoding drawing: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }


    
    
    
    
    private func saveDrawingToFirestore() {
        let drawing = canvasView.drawing
        let convertedDrawing = convertPKDrawingToCustomDrawing(drawing)
        
        do {
            let drawingData = try JSONEncoder().encode(convertedDrawing)
            let drawingDict = try JSONSerialization.jsonObject(with: drawingData, options: []) as? [[String: Any]]
            
            let db = Firestore.firestore()
            let drawingRef = db.collection("drawings").document()
            
            // Timestamp'i string olarak kaydedin
            let timestamp = Timestamp(date: Date())
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: timestamp.dateValue())
            
            let dataToSave: [String: Any] = [
                "drawings": drawingDict ?? [],
                "timestamp": timestampString
            ]
            
            drawingRef.setData(dataToSave) { error in
                if let error = error {
                    print("Error saving drawing: \(error.localizedDescription)")
                } else {
                    print("Drawing saved successfully!")
                }
            }
        } catch {
            print("Error encoding drawing: \(error.localizedDescription)")
        }
    }


    
    
    
    
    private func convertPKDrawingToCustomDrawing(_ pkDrawing: PKDrawing) -> [Drawing] {
        var drawings = [Drawing]()
        
        for stroke in pkDrawing.strokes {
            let color = CodableColor(color: stroke.ink.color)
            let lineWidth = stroke.path.first?.size.width ?? 1.0
            
            let points = stroke.path.map { point in
                return CodablePoint(point.location)
            }
            
            let drawing = Drawing(points: points, color: color, lineWidth: lineWidth)
            drawings.append(drawing)
        }
        
        return drawings
    }
    
    
    
    
    
    
    //pdf desteği
    //metal api vison os
    //macos app
    
    private func convertCustomDrawingToPKDrawing(_ customDrawings: [Drawing]) -> PKDrawing {
        var strokes = [PKStroke]()
        
        for customDrawing in customDrawings {
            let strokePoints = customDrawing.points.map { point -> PKStrokePoint in
                return PKStrokePoint(
                    location: point.toCGPoint(),
                    timeOffset: 0,
                    size: CGSize(width: customDrawing.lineWidth, height: customDrawing.lineWidth),
                    opacity: 1,
                    force: 1,
                    azimuth: .zero,
                    altitude: .zero
                )
            }
            
            let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
            let ink = PKInk(.pen, color: customDrawing.color.toUIColor())
            let stroke = PKStroke(ink: ink, path: strokePath)
            strokes.append(stroke)
        }
        
        return PKDrawing(strokes: strokes)
    }
}


























/*
class ViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver {

    private let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        return canvas
    }()

    private var toolPicker: PKToolPicker?
    
    class PostIt: UIView, UITextFieldDelegate {
        weak var parentViewController: ViewController?

        private let textField: UITextField = {
            let textField = UITextField()
            textField.backgroundColor = .clear
            textField.textColor = .black
            textField.textAlignment = .center
            textField.font = UIFont.systemFont(ofSize: 16)
            textField.placeholder = "Type something..."
            return textField
        }()

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .yellow
            setupPanGesture()
            setupTextField()
            setupDoneButtonAccessory()
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func setupPanGesture() {
            let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            addGestureRecognizer(panGesture)
            isUserInteractionEnabled = true
        }

        private func setupTextField() {
            textField.frame = bounds.insetBy(dx: 10, dy: 10)
            textField.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            textField.delegate = self
            addSubview(textField)
        }

        private func setupDoneButtonAccessory() {
            let toolbar = UIToolbar()
            toolbar.sizeToFit()

            let doneButton = UIBarButtonItem(title: "Tamam", style: .done, target: self, action: #selector(doneButtonTapped))
            toolbar.setItems([doneButton], animated: false)

            textField.inputAccessoryView = toolbar
        }

        @objc private func doneButtonTapped() {
            textField.resignFirstResponder()
            textFieldDidEndEditing()
        }

        @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                let translation = gesture.translation(in: superview)
                center = CGPoint(x: center.x + translation.x, y: center.y + translation.y)
                gesture.setTranslation(.zero, in: superview)
            default:
                break
            }
        }

        func textFieldDidBeginEditing() {
            if !textField.isFirstResponder {
                textField.becomeFirstResponder()
            }
        }

        func textFieldDidEndEditing() {
            if let parentVC = parentViewController {
                let toolPicker = PKToolPicker()
                toolPicker.setVisible(true, forFirstResponder: parentVC.canvasView)
                parentVC.canvasView.becomeFirstResponder()
            }
        }

        func getText() -> String? {
            return textField.text
        }

        func setText(_ text: String) {
            textField.text = text
        }
    }

    private let toolbar = UIToolbar()

    override func viewDidLoad() {
        super.viewDidLoad()

        canvasView.delegate = self
        view.addSubview(canvasView)
    let toolpicker = PKToolPicker()
        
        toolpicker.setVisible(true, forFirstResponder: canvasView)
        toolpicker.addObserver(canvasView)
        toolpicker.addObserver(self)
        canvasView.becomeFirstResponder()

        setupToolbar()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasView.frame = view.bounds

        toolbar.frame = CGRect(x: 0, y: view.frame.height - toolbar.frame.height, width: view.frame.width, height: toolbar.frame.height)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }

    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        canvasView.tool = toolPicker.selectedTool
    }

    private func setupToolbar() {
        let postItButton = UIBarButtonItem(title: "Add Post-it", style: .plain, target: self, action: #selector(addPostIt))
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        toolbar.items = [flexibleSpace, postItButton]
        toolbar.sizeToFit()

        view.addSubview(toolbar)
    }

    @objc private func addPostIt() {
        let postItView = PostIt(frame: CGRect(x: 50, y: 50, width: 200, height: 200))
        postItView.backgroundColor = UIColor.systemPink.withAlphaComponent(0.8)
        postItView.layer.cornerRadius = 10
        postItView.layer.borderWidth = 1
        postItView.layer.borderColor = UIColor.black.cgColor
        postItView.parentViewController = self

        postItView.setText("")

        view.addSubview(postItView)

        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }

    // Diğer metodlar burada olacak (saveDrawingToFirestore, bringDrawingsFromFirestore, convertPKDrawingToCustomDrawing, convertCustomDrawingToPKDrawing)




    
    
    
    
    @IBAction func SaveItem(_ sender: Any) {
        saveDrawingToFirestore()
    }
    
    @IBAction func bringDrawing(_ sender: Any) {
        bringDrawingsFromFirestore { drawings in
            if let drawings = drawings {
                let pkDrawing = self.convertCustomDrawingToPKDrawing(drawings)
                self.canvasView.drawing = pkDrawing
                print("Çizim başarıyla yüklendi!")
            } else {
                print("Çizim alınamadı veya hata oluştu.")
            }
        }
    }
    
    private func bringDrawingsFromFirestore(completion: @escaping ([Drawing]?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("drawings")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting drawings: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No drawings found")
                    completion(nil)
                    return
                }
                
                do {
                    let drawings = try documents.compactMap { document -> [Drawing]? in
                        let data = document.data()
                        guard let drawingArray = data["drawings"] as? [[String: Any]] else {
                            print("Drawing array not found in Firestore document")
                            return nil
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: drawingArray, options: [])
                        return try JSONDecoder().decode([Drawing].self, from: jsonData)
                    }.flatMap { $0 }
                    
                    completion(drawings)
                } catch {
                    print("Error decoding drawing: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }
  
   

    
    private func saveDrawingToFirestore() {
        let drawing = canvasView.drawing
        let convertedDrawing = convertPKDrawingToCustomDrawing(drawing)
        
        do {
            let drawingData = try JSONEncoder().encode(convertedDrawing)
            let drawingDict = try JSONSerialization.jsonObject(with: drawingData, options: []) as? [[String: Any]]
            
            let db = Firestore.firestore()
            let drawingRef = db.collection("drawings").document()
            
            let timestamp = Timestamp(date: Date())
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: timestamp.dateValue())
            
            let dataToSave: [String: Any] = [
                "drawings": drawingDict ?? [],
                "timestamp": timestampString
            ]
            
            drawingRef.setData(dataToSave) { error in
                if let error = error {
                    print("Error saving drawing: \(error.localizedDescription)")
                } else {
                    print("Drawing saved successfully!")
                }
            }
        } catch {
            print("Error encoding drawing: \(error.localizedDescription)")
        }
    }
    
    private func convertPKDrawingToCustomDrawing(_ pkDrawing: PKDrawing) -> [Drawing] {
        var drawings = [Drawing]()
        
        for stroke in pkDrawing.strokes {
            let color = CodableColor(color: stroke.ink.color)
            let lineWidth = stroke.path.first?.size.width ?? 1.0
            
            let points = stroke.path.map { point in
                return CodablePoint(point.location)
            }
            
            let drawing = Drawing(points: points, color: color, lineWidth: lineWidth)
            drawings.append(drawing)
        }
        
        return drawings
    }
    
    private func convertCustomDrawingToPKDrawing(_ customDrawings: [Drawing]) -> PKDrawing {
        var strokes = [PKStroke]()
        
        for customDrawing in customDrawings {
            let strokePoints = customDrawing.points.map { point -> PKStrokePoint in
                return PKStrokePoint(
                    location: point.toCGPoint(),
                    timeOffset: 0,
                    size: CGSize(width: customDrawing.lineWidth, height: customDrawing.lineWidth),
                    opacity: 1,
                    force: 1,
                    azimuth: .zero,
                    altitude: .zero
                )
            }
            
            let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
            let ink = PKInk(.pen, color: customDrawing.color.toUIColor())
            let stroke = PKStroke(ink: ink, path: strokePath)
            strokes.append(stroke)
        }
        
        return PKDrawing(strokes: strokes)
    }

    
    
    
    
}

*/




/*
import UIKit
import PencilKit
import Firebase
import FirebaseFirestore


class ViewController: UIViewController, PKCanvasViewDelegate, PKToolPickerObserver {
    
    private let canvasView: PKCanvasView = {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        return canvas
    }()
    
    private var toolPicker: PKToolPicker?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // CanvasView and toolPicker setup
        canvasView.delegate = self
        view.addSubview(canvasView)
        
        toolPicker = PKToolPicker()
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        toolPicker?.addObserver(self)
        canvasView.becomeFirstResponder()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        canvasView.frame = view.bounds
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Make Tool Picker visible and set canvasView as first responder
        toolPicker?.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }
    
    func toolPickerSelectedToolDidChange(_ toolPicker: PKToolPicker) {
        // Apply the selected tool to canvasView
        canvasView.tool = toolPicker.selectedTool
    }
    
    @IBAction func SaveItem(_ sender: Any) {
        saveDrawingToFirestore()
    }
    
    @IBAction func bringDrawing(_ sender: Any) {
        bringDrawingsFromFirestore { drawings in
            if let drawings = drawings {
                // Çizimleri PKDrawing'e dönüştür
                let pkDrawing = self.convertCustomDrawingToPKDrawing(drawings)
                
                // canvasView'ı güncelle
                self.canvasView.drawing = pkDrawing
                print("Çizim başarıyla yüklendi!")
            } else {
                print("Çizim alınamadı veya hata oluştu.")
            }
        }
    }
    
    
    
    
    
    
    
    private func bringDrawingsFromFirestore(completion: @escaping ([Drawing]?) -> Void) {
        let db = Firestore.firestore()
        
        db.collection("drawings")
            .order(by: "timestamp", descending: true)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("Error getting drawings: \(error.localizedDescription)")
                    completion(nil)
                    return
                }
                
                guard let documents = snapshot?.documents, !documents.isEmpty else {
                    print("No drawings found")
                    completion(nil)
                    return
                }
                
                do {
                    let drawings = try documents.compactMap { document -> [Drawing]? in
                        let data = document.data()
                        
                        // Veriyi "drawings" alanı altında bir dizi olarak beklediğimizden emin olalım
                        guard let drawingArray = data["drawings"] as? [[String: Any]] else {
                            print("Drawing array not found in Firestore document")
                            return nil
                        }
                        
                        let jsonData = try JSONSerialization.data(withJSONObject: drawingArray, options: [])
                        return try JSONDecoder().decode([Drawing].self, from: jsonData)
                    }.flatMap { $0 }
                    
                    completion(drawings)
                } catch {
                    print("Error decoding drawing: \(error.localizedDescription)")
                    completion(nil)
                }
            }
    }


    
    
    
    
    private func saveDrawingToFirestore() {
        let drawing = canvasView.drawing
        let convertedDrawing = convertPKDrawingToCustomDrawing(drawing)
        
        do {
            let drawingData = try JSONEncoder().encode(convertedDrawing)
            let drawingDict = try JSONSerialization.jsonObject(with: drawingData, options: []) as? [[String: Any]]
            
            let db = Firestore.firestore()
            let drawingRef = db.collection("drawings").document()
            
            // Timestamp'i string olarak kaydedin
            let timestamp = Timestamp(date: Date())
            let dateFormatter = ISO8601DateFormatter()
            let timestampString = dateFormatter.string(from: timestamp.dateValue())
            
            let dataToSave: [String: Any] = [
                "drawings": drawingDict ?? [],
                "timestamp": timestampString
            ]
            
            drawingRef.setData(dataToSave) { error in
                if let error = error {
                    print("Error saving drawing: \(error.localizedDescription)")
                } else {
                    print("Drawing saved successfully!")
                }
            }
        } catch {
            print("Error encoding drawing: \(error.localizedDescription)")
        }
    }


    
    
    
    
    private func convertPKDrawingToCustomDrawing(_ pkDrawing: PKDrawing) -> [Drawing] {
        var drawings = [Drawing]()
        
        for stroke in pkDrawing.strokes {
            let color = CodableColor(color: stroke.ink.color)
            let lineWidth = stroke.path.first?.size.width ?? 1.0
            
            let points = stroke.path.map { point in
                return CodablePoint(point.location)
            }
            
            let drawing = Drawing(points: points, color: color, lineWidth: lineWidth)
            drawings.append(drawing)
        }
        
        return drawings
    }
    
    
    
    
    
    
    //pdf desteği
    //metal api vison os
    //macos app
    
    private func convertCustomDrawingToPKDrawing(_ customDrawings: [Drawing]) -> PKDrawing {
        var strokes = [PKStroke]()
        
        for customDrawing in customDrawings {
            let strokePoints = customDrawing.points.map { point -> PKStrokePoint in
                return PKStrokePoint(
                    location: point.toCGPoint(),
                    timeOffset: 0,
                    size: CGSize(width: customDrawing.lineWidth, height: customDrawing.lineWidth),
                    opacity: 1,
                    force: 1,
                    azimuth: .zero,
                    altitude: .zero
                )
            }
            
            let strokePath = PKStrokePath(controlPoints: strokePoints, creationDate: Date())
            let ink = PKInk(.pen, color: customDrawing.color.toUIColor())
            let stroke = PKStroke(ink: ink, path: strokePath)
            strokes.append(stroke)
        }
        
        return PKDrawing(strokes: strokes)
    }
}


*/
















//
//  Drawing.swift
//  PaintApplication
//
//  Created by EBRU KÖSE on 16.08.2024.
//



import UIKit
import Foundation


struct CodablePoint: Codable {
    var x: CGFloat
    var y: CGFloat
    
    init(_ point: CGPoint) {
        self.x = point.x
        self.y = point.y
    }
    
    func toCGPoint() -> CGPoint {
        return CGPoint(x: x, y: y)
    }
}

struct CodableColor: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat
    
    init(color: UIColor) {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    func toUIColor() -> UIColor {
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        
    }
  
}




struct Drawing: Codable {
    var points: [CodablePoint]
    var color: CodableColor
    var lineWidth: CGFloat
}



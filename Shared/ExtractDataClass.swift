//
//  ExtractDataClass.swift
//  FITSDocument
//
//  Created by Matthew Malaker on 2/17/22.
//
// used to thread subtract dark view

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


class ExtractDataClass: NSObject, ObservableObject{
    
    func extractFloatData(Data: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]) {
        
        
        let floatData = returnRawFloat(RawData: Data)

            return floatData
        }
    
    func returnRawFloat(RawData : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]){
        
        //Buffer from FITS File
        
        
        let buffer = RawData.1
        
        //destination buffer
        let width :Int = Int(buffer.width)
        let height: Int = Int(buffer.height)

        var OriginalPixelData = (buffer.data.toArray(to: Float.self, capacity: Int(buffer.width*buffer.height)))
        

        OriginalPixelData = (buffer.data.toArray(to: Float.self, capacity: Int(width*height)))
         
        print("called")
        return(OriginalPixelData)
        }
    
    
    
}

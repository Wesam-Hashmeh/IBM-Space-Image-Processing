//
//  FileReadIn.swift
//  FITSDocument
//
//  Created by Megan Burrill on 3/24/22.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


class FileReadIn: NSObject, ObservableObject{
    
    var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    func returnDataFromFile(selectedFile: URL, width: Int, height: Int) -> (URL, [Float], Int, Int){
        var imageHeight = 2080
        var imageWidth = 3072
        var floatDataFromFITSFile :[Float] = []
                    print("Selected file is", selectedFile)

                    //trying to get access to url contents
                    if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {


                        guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return (URL(string: "")! ,[0], 0, 0) }
                        let prime = read_data.prime
                        print(prime)
                        prime.v_complete(onError: {_ in
                            print("CGImage creation error")
                        }) { result in

                            self.rawDataFromFITSFile = result

                            floatDataFromFITSFile = self.extractFloatData(Data: self.rawDataFromFITSFile!)

                            //Buffer from FITS File
                            let buffer = self.rawDataFromFITSFile!.1
                            //destination buffer

                            if ((imageWidth == 0) && (imageHeight == 0)){

                                imageWidth = Int(buffer.width)
                                imageHeight = Int(buffer.height)

                            }
                            else if (imageWidth != Int(buffer.width)) || (imageHeight != Int(buffer.height)){

                                print("Image sizes do not match.")
                                return
                            }
                        }


                        //done accessing the url
                        CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)


                    }
                    else {
                        print("Permission error!")
                    }
            return (selectedFile, floatDataFromFITSFile, imageWidth, imageHeight)
    }
    
    func extractFloatData(Data: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]) {
        
        
        let floatData = returnRawFloat(RawData: Data)

            return floatData
        }
    
    
}

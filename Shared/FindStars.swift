//
//  FindStars.swift
//  FITSDocument
//
//  Created by Jeff Terry on 10/4/21.
//

import SwiftUI

struct FindStars: View {
    
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    
    @State var selectedImage = ""
    
    @State var imageArray :[String] = [
    "Empty"]
    
    var body: some View {
        
        VStack{
            Button(action: {PopulateImageField()}, label: {
                            Text("Populate Images")
                        })
            //.disabled(document == nil)
            Spacer()
            
            Button(action: {locateStarsWithGaussianFit(nameOfSelectedDocument: selectedImage)}, label: {
                            Text("Find The Stars")
                        })
            
            Spacer()
            
            
            Picker("Select an Image", selection: $selectedImage) {
                ForEach($imageArray.wrappedValue, id: \.self) {
                                Text($0)
                            }
                }
            /*.onReceive([self.selectedImage].publisher.first()) { value in
                        self.doSomethingWith(value: value)
             }*/
        
        }
        
    }
    
    /// removes all data from the image array, and then selects chosen .fits file from the database. It then prints the "height" of the data
    func PopulateImageField(){
        
        imageArray.removeAll()
        
        imageArray.append(contentsOf: listOfDocuments.documentName)
        
        let starDocument = listOfDocuments.documentList[0]
        
        print(starDocument.imageHeight)
        
        let imageHeight = starDocument.imageHeight.wrappedValue
        
        print(imageHeight)
        
        print("Finding Stars")
        print(document)
        
    }
    
    
    /// Locate Stars Then Do a 2D Gaussian fit to refine them.
    /// - Parameter nameOfSelectedDocument: Document that contains the image data (array of floats) that will be used to find the stars
    ///
    func locateStarsWithGaussianFit(nameOfSelectedDocument: String) {
           print(nameOfSelectedDocument)
        
        
        if let index = listOfDocuments.documentName.firstIndex(of: nameOfSelectedDocument) {
            
            // Get the Address of the Selected Document
               dataFloat = listOfDocuments.documentList[index]
               
               dataWidth =  listOfDocuments.documentList[index].imageWidth.wrappedValue
               
               dataHeight = listOfDocuments.documentList[index].imageHeight.wrappedValue
            }
        
//        print(dataFloat!.wrappedValue.ImageInfo!.4[3])
//        print(dataFloat!.wrappedValue.ImageInfo!.4[6])
//        print(dataFloat!.wrappedValue.ImageInfo!.4[780])
        
        //Get the floating point array of image values from the selected Document
        let imageData = dataFloat!.wrappedValue.ImageInfo!.4
        
        
        let relativePeakLimit = imageData.max()!*0.020
        //let relativePeakLimit = imageData.max()!*0.10
        
        var centroidCoordinatesOfPossibleStars :[xy_coord] = []
        
        centroidCoordinatesOfPossibleStars = findTheStars(imageData: imageData, width: Int(dataWidth!), height: Int(dataHeight!), relativePeakLimit: relativePeakLimit)
        
        //print(centroidCoordinatesOfPossibleStars)
        
        //make array for star image
        var starArray :[Float] = Array(repeating: 0.0, count: Int(dataWidth!*dataHeight!))
        
        for item in centroidCoordinatesOfPossibleStars {
            
            starArray[Int(item.x) + Int(item.y) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x - 1) + Int(item.y - 1) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x - 1) + Int(item.y) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x - 1) + Int(item.y + 1) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x) + Int(item.y - 1) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x) + Int(item.y + 1) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x + 1) + Int(item.y) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x + 1) + Int(item.y - 1) * Int(dataWidth!)] = 1.0
            starArray[Int(item.x + 1) + Int(item.y + 1) * Int(dataWidth!)] = 1.0

            
        }
        
        let rowBytes :Int = Int(dataWidth!) * MemoryLayout<Float>.size
        
        let starImage = returningCGImage(data: starArray, width: Int(dataWidth!), height: Int(dataHeight!), rowBytes: rowBytes)
        
        
        dataFloat!.wrappedValue.starImage = starImage
        
     }
}

/// Function finds stars by finding high data values within the chosen .fits file
/// - Parameters:
///   - imageData: Data from the chosen .fits file
///   - width: width of the chosen .fits file
///   - height: height of the chosen .fits file
///   - relativePeakLimit: Finds the highest floating integer datapoint in the chunk of the image.
/// - Returns: <#description#>
func findTheStars(imageData: [Float], width: Int, height: Int, relativePeakLimit: Float) -> [xy_coord]{
    
    let maximumIntensity = imageData.max()
    
    print("Max intensity found ", maximumIntensity ?? 0.0)
    
    //Create Normalized Image
    
    var normalizedData :[Float] = []
    
    for item in imageData{
        
        normalizedData.append(item/maximumIntensity!)
    }
    
    var chunkSize = 17
    
    if (((width/100)%2) != 0){
        
        chunkSize = Int(width/100)
    }
    else {
        
        chunkSize = Int(width/100) + 1
    }
    
    if (chunkSize < 11) {
        
        chunkSize = 11
    }
    
    print("chunkSize =", chunkSize)
    var halfChunkSizeRoundedDown = Int( floor((Double(chunkSize)/2.0)))
    
    var centerX = 0
    var centerY = 0
 
    var centroidCoordinates :[xy_coord] = []
    
    
    //Identifying points where a gaussian fit will be attempted (does not do yet)
    
    print("Running preliminary star finder loops")
    
    for centerY in stride(from: halfChunkSizeRoundedDown, to: (height - halfChunkSizeRoundedDown), by: chunkSize) {
        
        for centerX in stride(from: halfChunkSizeRoundedDown, to: (width - halfChunkSizeRoundedDown), by: chunkSize) {
            
            //Create the check array
            var testArray :[Float] = []
            
            for y in stride(from: centerY-halfChunkSizeRoundedDown, through: centerY+halfChunkSizeRoundedDown, by: 1){
                
                for x in stride(from: centerX-halfChunkSizeRoundedDown, through: centerX+halfChunkSizeRoundedDown, by: 1){
                    
                    testArray.append(imageData[x + y*width])
                    
                    
                }
                
                
            }
            
            let returnedCoordinates = findMaximumValueInChuck(image: testArray, centerX: centerX, centerY: centerY, chunkSize: chunkSize, relativePeakLimit: relativePeakLimit)
            
            if (returnedCoordinates.y > 0.0) {
                
                centroidCoordinates.append(returnedCoordinates)

            }
            
        }
    }
    
    print("Found ", centroidCoordinates.count, "places to check a gaussian fit")
    
    return(centroidCoordinates)
    
}

/// Function utilized to find the highest data point within a chunk of the image. May be mispelled, though there is a "findmaximumvalueinchunk" function utilized in StarCoordinateLocator, so who knows, really -DB
/// - Parameters:
///   - image: referring oto the data of the image itself, used to pull the raw data of the file, like looking for the maximum values in each of hte chunks.
///   - centerX: Rounded estimate of the central x-coordinate of the image
///   - centerY: Rounded estimate to the nearest integer of the central y-coordinate of the image.
///   - chunkSize: Determined by the pixel width of the image, width/100 pixels
///   - relativePeakLimit: <#relativePeakLimit description#>
/// - Returns: <#description#>
func findMaximumValueInChuck(image: [Float], centerX: Int, centerY: Int, chunkSize: Int, relativePeakLimit: Float ) -> xy_coord {
    
    let max = image.max()
    
    if ((max! <= relativePeakLimit) || (max! >= 0.95 )){
        
        let returnCoordinate = xy_coord(x: -1.0, y: -1.0)
        
        return returnCoordinate
    }
  
    let deviation = image.stdev
    
    if deviation! < (relativePeakLimit*0.1) {
        
        //let returnCoordinate = xy_coord(x: Double(centerX), y: Double(centerY))
        
        let returnCoordinate = xy_coord(x: -1.0, y: -1.0)
        
        return returnCoordinate
        
    }
    
    let halfChunkSizeRoundedDown :Int = Int(floor((Double(chunkSize)/2.0)))
    
    var chunkAverage = 0.0
    
    
    //printf("%f\n",valueCenter);
    
    var isBiggest = true
    var isPeak = false
    
    var x = 0
    var y = 0
    
    //Checking for the maximum value
    
    for deltaY in stride(from: -halfChunkSizeRoundedDown, to: (halfChunkSizeRoundedDown), by: 1) {
        
        for deltaX in stride(from: -halfChunkSizeRoundedDown, to: halfChunkSizeRoundedDown, by: 1) {
            
            let valueChecking = image[(deltaX + halfChunkSizeRoundedDown) + (deltaY + halfChunkSizeRoundedDown)*chunkSize]
            
            if (abs(valueChecking-max!) < (max!.ulp*5) ) {
                
                x = centerX + deltaX
                y = centerY + deltaY
                
                break
            }
        }
    }
    
    
    let returnCoordinate = xy_coord(x: Double(x), y: Double(y))
    
    return returnCoordinate
}


/// FUNCTION DOES NOT EXIST. FUTURE LABORERS, IMPLEMENT THIS FEATURE -DB
/// - Parameters:
///   - image: raw data from the chosen .fits file
///   - centerX: Rounded integer of the central x-coordinate
///   - centerY: Rounded integer of the central y-coordinate
///   - width: width of the .fits file, in pixels
///   - height: height of the .fits file, in pixels
///   - chunkSize: slice of the .fits file determined by the width of the image
///   - relativePeakLimit: highest data value within each chunk.
/// - Returns: <#description#>
func shouldAttemptGaussianFitAtThisPoint(image: [Float], centerX: Int, centerY: Int, width: Int, height: Int, chunkSize: Int, relativePeakLimit: Double ) -> Bool {
    
    let halfChunkSizeRoundedDown :Int = Int(floor((Double(chunkSize)/2.0)))
    
    var chunkAverage = 0.0
    
    let valueCenter = image[centerX + centerY * width]
    
    
    //printf("%f\n",valueCenter);
    
    var isBiggest = true
    var isPeak = false
    
    //Checks if center pixel is the highest in the chunk. Also calculating average
    
    for checkingY in stride(from: centerY - halfChunkSizeRoundedDown, to: (centerY + halfChunkSizeRoundedDown), by: 1) {
        
        for checkingX in stride(from: centerX - halfChunkSizeRoundedDown, to: (centerX + halfChunkSizeRoundedDown), by: 1) {
            
            let valueChecking = image[checkingX + checkingY*width]
            
            if (checkingY != centerY || checkingX != centerX) { //Don't check against itself
                if ( valueChecking >= valueCenter ) {
                    isBiggest = false;
                }
            }
        }
    }
    
    
    if (isBiggest) {
        return true
    }
    
    return false
}

struct FindStars_Previews: PreviewProvider {
    static var previews: some View {
        FindStars()
    }
}

struct xy_coord {
    var x :Double
    var y :Double
};

struct triangle {
    var identifier :Int
    var pointA :xy_coord
    var pointB :xy_coord
    var pointC :xy_coord
    
    var AB_length :Double //Shortest
    var AC_length :Double
    var BC_length :Double //Longest
    
    //Similar triangle if AB_length=1
    var AC_normalized :Double
    var BC_normalized :Double
    
    //hash=BC_normalized/AC_normalized
    var hash :Double
};

struct plateConstants {
    // X = ax + by + c
    var a :Double
    var b :Double
    var c :Double
    // Y = dx + ey + f
    var d :Double
    var e :Double
    var f :Double
    //Capital letters are on the plane tangent to the celestial sphere
    //Lower case are the plate coords
};

struct gaussParams {
    // f(x,y)=A*exp(-((x-x0)^2+(y-y0)^2)/B)
    var A :Double
    var B :Double
    var x0 :Double
    var y0 :Double
    var residual :Double
};

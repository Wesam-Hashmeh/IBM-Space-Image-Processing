//
//  AddImages.swift
//  AddImages
//
//  Created by Jeff_Terry on 12/3/21.
//

import SwiftUI

import SwiftUI
import UniformTypeIdentifiers
import FITS
import FITSKit
import Accelerate


struct AddImages: View {
    @EnvironmentObject var listOfDocuments: DocumentList
    
    @FocusedBinding(\.document) var document
    
    @State var dataFloat :DocumentBinding? = nil
    @State var dataWidth :UInt? = nil
    @State var dataHeight :UInt? = nil
    
    @State var selectingFilesToAdd: Bool = false
    
    @State var selectingFilesToSave: Bool = false
    
    @State var rawDataFromFITSFile : ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)?
    
    @State var imageHeight = 0
    @State var imageWidth = 0
    
    
    @State var summedFloatingArray :[Float] = []
    
    @State var summedDocument = FITSDocumentDocument(text: "Hello, world!")
    
//    @State var deviationArray :[Float] = []
//    @State var meanArray :[Float] = []
//    @State var pointArray :[Float] = []
    
    let numberOfStandardDeviationsAway = 1.5
    
    /* This may not be the best way to do this. May be better to load in the image multiple times rather than try to store in memory */
   // @State var dataFromAllTheImagesToCombine :[[Float]] = []
    
    @State var selectedImage = ""
    
    @State var imageArray :[URL] = []
    
    @State var summedImage :CGImage?
    
    var body: some View {
        
        VStack{
            
            Spacer()
            
            
            Button("Select the Files To Combine") {
                imageArray.removeAll()
                summedFloatingArray.removeAll()
                selectingFilesToAdd.toggle()
                    }
                .fileImporter(
                        isPresented: $selectingFilesToAdd,
                        allowedContentTypes: [.fitDocument],
                        allowsMultipleSelection: true,
                        onCompletion: { result in
                            print("Picked: \(result)")
                            
                            let fileUrlsToAdd = try? result.get()

                            imageArray.append(contentsOf: fileUrlsToAdd!)

                            print(imageArray)
//                            var myFileReadIn = FileReadIn()
//
//                            let dataToReturn : (URL, [Float], Int, Int) = myFileReadIn.returnDataFromFile(selectedFile: imageArray[0], width: 0, height: 0)
                            //imageWidth = dataToReturn.2
                            //imageHeight = dataToReturn.3
                            
                        })
            
            Spacer()
            
            
            Button("Merge Selected Files", action: {Task.init{
                                
                                //print("Start time \(Date())\n")
                                await self.loadAndSum()}})
                                
            
            
            Button("Save"){
                
                saveFile()
                selectingFilesToSave = true
                
            }
            .fileExporter(isPresented: $selectingFilesToSave, document: summedDocument, contentType: .fitDocument, defaultFilename: "Summed", onCompletion: { result in
                print("Picked: \(result)")
                
//                let fileUrlsToAdd = try? result.get()
//
//                imageArray.append(contentsOf: fileUrlsToAdd!)
//
//                print(imageArray)
            })
            
            
           
            
            VStack{
                //rawImage?.resizable().scaledToFit()
                if (summedImage != nil){
                    Image((summedImage!), scale: 2.0, label: Text("Raw")).resizable().scaledToFit()
                }
            }

            
        
        
        }
                
    }

    func saveFile(){
        
        let floatData :[FITSByte_F] = summedDocument.rawFloatData.bigEndian

        summedDocument.myPrimaryHDU = PrimaryHDU(width: imageWidth, height: imageHeight, vectors: floatData)
        
        
        print(summedDocument.myPrimaryHDU)
    }
    
//    func loadSubsectionOfImages(arrayofImageFiles: [URL]) -> [[Float]]{
        
  //      var dataFromTheSubsectionToCombine :[[Float]] = []
    //    for item in arrayofImageFiles

      //  {
        //            let selectedFile: URL = item

          //              print("Selected file is", selectedFile)

                        //trying to get access to url contents
            //            if (CFURLStartAccessingSecurityScopedResource(selectedFile as CFURL)) {


              //              guard let read_data = try! FitsFile.read(contentsOf: selectedFile) else { return dataFromTheSubsectionToCombine }
                //            let prime = read_data.prime
                  //          print(prime)
                    //        prime.v_complete(onError: {_ in
                      //          print("CGImage creation error")
                        //    }) { result in

                          //          rawDataFromFITSFile = result

                            //    let floatDataFromFITSFile :[Float] = self.extractFloatData(Data: rawDataFromFITSFile!)

                                //Buffer from FITS File
                              //  let buffer = rawDataFromFITSFile!.1
                                //destination buffer
                                //if ((imageWidth == 0) && (imageHeight == 0)){

                                  //  imageWidth = Int(buffer.width)
                                    //imageHeight = Int(buffer.height)

                                //}
                                //else if (imageWidth != Int(buffer.width)) || (imageHeight != Int(buffer.height)){

                                  //  print("Image sizes do not match.")
                                    //return
                                //}

                                //dataFromTheSubsectionToCombine.append(floatDataFromFITSFile)



                            //}


                            //done accessing the url
                            //CFURLStopAccessingSecurityScopedResource(selectedFile as CFURL)


                        //}
                        //else {
                          //  print("Permission error!")
                        //}

             //   }
//
       // return dataFromTheSubsectionToCombine
   // }

    func loadSubsectionOfImages(arrayofImageFiles: [URL]) async -> [[Float]] {
        //let dataFromTheSubsectionToCombine = Task{ () -> [[Float]] in
                    
        
        
            var dataFromTheSubsectionToReturn :[[Float]] = []
                    
                    
                    let dataReturnFromTaskGroup = await withTaskGroup(of: (URL, [Float], Int, Int).self, /* this is the return from the taskGroup*/
                                                              returning: [(URL, [Float], Int, Int)].self, /* this is the return from the result collation */
                                                              body: { taskGroup in  /*This is the body of the task*/
                        
                        // We can use `taskGroup` to spawn child tasks here.
                        
                        
                        for item in arrayofImageFiles{
                            
                            taskGroup.addTask{
                                
                                var myFileReadIn = FileReadIn()
                                
                                let dataToReturn : (URL, [Float], Int, Int) = myFileReadIn.returnDataFromFile(selectedFile: item, width: 0, height: 0)
                                
                                await updateImageParameters(width: dataToReturn.2, height: dataToReturn.3)
                                
                                return dataToReturn
                            }
                            
                        }
                        
                        
                        var interimResults: [(URL, [Float], Int, Int)] = []
                        
                        for await result in taskGroup{
                            
                            
                            interimResults.append(result)
                        }
                        return interimResults
                        })
                    
            
            
                      //Do whatever processing that you need with the returned results of all of the child tasks here.
                      
                 
        dataFromTheSubsectionToReturn = await sortCombinedResults(dataReturnFromTaskGroup: dataReturnFromTaskGroup)
            print("About to return data from the subsection to return")
            print(dataFromTheSubsectionToReturn.count)
            return dataFromTheSubsectionToReturn
      //  }
        

        
    }
    
    /// Sorts data based on index of the result of the variable.
    /// - Parameter dataReturnFromTaskGroup: <#dataReturnFromTaskGroup description#>
    /// - Returns: <#description#>
    func sortCombinedResults(dataReturnFromTaskGroup : [(URL, [Float], Int, Int)]) async -> [[Float]]
    
    {
        var dataFromTheSubsectionToReturn : [[Float]] = []
             // Sort the results based upon the index of the result
             let sortedCombinedResults = dataReturnFromTaskGroup.sorted(by: { String(describing: $0.0) < String(describing: $1.0) })
             
             for item in sortedCombinedResults{
                 
                 // Display the sorted text in the GUI
                //print (item)
                 dataFromTheSubsectionToReturn.append(item.1)
                 
             }
        return dataFromTheSubsectionToReturn
    }
    
//
//        var dataFromTheSubsectionToCombine :[[Float]] = []
//        Task {
//            let dataReturnFromTaskGroup = await withTaskGroup(of: [[Float]].self, /*this is the return from the taskgroup*/ returning: [[Float]].self, /* this is the return from the result collation*/ body: { taskGroup in /*this is the body of the task*/
//            for item in arrayofImageFiles{
//                taskGroup.addTask{
//                    var myFileReadIn = FileReadIn()
//                    return myFileReadIn.returnDataFromFile(selectedFile: item, width: 0, height: 0)
//                }
//            }
//            var interimResults: [[Float]] = []
//            for await result in taskGroup{
//                let floatDataFromFITSFile :[Float] = result.1
//                interimResults.append(floatDataFromFITSFile)
//            }
//            return interimResults
//            })
//            return dataReturnFromTaskGroup
//    }
    
    
    
    
    

//    func sumSubsectionOfImages(dataFromAllTheImagesToCombine: [[Float]], arrayOfValuesInPixels: [[Int]])-> (imageData: [Float], pixelContribution: [Int]){
//
//        var deviation :[Float] = []
//        var mean :[Float] = []
//        var pointArray :[Float] = []
//        var contributionOfEachPixel :[Int] = Array(repeating: 1, count: imageHeight*imageWidth)
//        var summedFloatArray :[Float] = Array(repeating: 0.0, count: imageHeight*imageWidth)
//
//
//        if dataFromAllTheImagesToCombine.count == 0 {
//
//
//            return (imageData: summedFloatArray, pixelContribution: contributionOfEachPixel)
//
//
//        }
//
//
//        // Calculate Standard Deviation and Mean
//
//        for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){
//
//            pointArray.removeAll()
//
//            for arrayNumber in stride(from: 0, to: dataFromAllTheImagesToCombine.count, by: 1){
//
//            //for floatingArray in dataFromAllTheImagesToCombine {
//
//                let floatingArray = dataFromAllTheImagesToCombine[arrayNumber]
//                let thePixelContribution = arrayOfValuesInPixels[arrayNumber]
//
//
//                pointArray.append(floatingArray[pixel]*Float(thePixelContribution[pixel]))
//
//
//            }
//
//
//           mean.append(pointArray.mean)
//            if (pointArray.count > 1){
//
//                deviation.append(pointArray.stdev!)
//            }
//            else{
//
//                deviation.append(pointArray.stdevp!)
//            }
//
//
//
//        }
//
//
//        // Sum if the pixel is within numberOfStandardDeviationsAway from the mean
//
//
//        for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){
//
//            var sumCounter = 0
//
//            for floatingArray in dataFromAllTheImagesToCombine {
//
//                if (abs(floatingArray[pixel]-mean[pixel]) <= Float(numberOfStandardDeviationsAway)*deviation[pixel] ){
//
//                    sumCounter += 1
//
//                    summedFloatArray[pixel] = (summedFloatArray[pixel]*Float(sumCounter - 1) + floatingArray[pixel])/Float(sumCounter)
//
//
//
//
//                }
//
//
//            }
//
////            print(summedFloatArray[pixel], sumCounter )
//            //summedFloatArray[pixel] *= 10
//
//        }
//
//        return (imageData: summedFloatArray, pixelContribution: contributionOfEachPixel)
//    }





    func loadAndSum() async{
        
        await combineMultiple()
        
    }
    
    /// Sets a min/max value to the number of images that can be processed in a step (40/200 respectively). Makes a loop while stopLoopvalue is less than Imagearraycount, Combines starter image with an image from the WaitingtobeCombined variable, I think.
    func combineMultiple() async {
    
    //imageHeight = 0
    //imageWidth = 0
    
//       dataFromAllTheImagesToCombine.removeAll()
//        deviationArray.removeAll()
//        meanArray.removeAll()
    
    
    var dataFromAllTheStepsToCombine :[[Float]] = []
    var summedAllImageFloatArray :[Float] = Array(repeating: 0.0, count: imageHeight*imageWidth)
    var weightingFactor :[Float] = []
    
    
    let imageArrayCount = imageArray.count
    
    var stopLoopValue = 0
    var startLoopValue = 0
    var counter = 0
    var imageStep = 0
    var preferedMinimumNumberOfImagesToProcessInAStep = 40
    var maximumNumberOfImagesToProcessInAStep = 200
    
    if (imageArrayCount < preferedMinimumNumberOfImagesToProcessInAStep) {
        
        imageStep = imageArrayCount
        
    }
    else if (imageArrayCount/preferedMinimumNumberOfImagesToProcessInAStep > maximumNumberOfImagesToProcessInAStep) {
        
        imageStep = maximumNumberOfImagesToProcessInAStep
        
        
    }
    else {
        
        let divisor = imageArrayCount/preferedMinimumNumberOfImagesToProcessInAStep
        imageStep = imageArrayCount/divisor
        
    }
    
    
    while stopLoopValue < imageArrayCount {
        
        var subsetImageArray :[URL] = []
        var dataFromTheSubsectionsToCombine :[[Float]] = []
        var weight = Float(0.0)
        
        startLoopValue = stopLoopValue
        counter += 1
        stopLoopValue = counter*imageStep
        
        if stopLoopValue > imageArrayCount {
            
            stopLoopValue = imageArrayCount
        }
        
        weight = Float(stopLoopValue - startLoopValue)
        
        
        for imageCounter in stride(from: startLoopValue, to: stopLoopValue, by: 1){
            
            
            subsetImageArray.append(imageArray[imageCounter])
            
            
        }
        //learn to spell, you guys.
        print("before data from the subestion to combine ")
        dataFromTheSubsectionsToCombine = await loadSubsectionOfImages(arrayofImageFiles: subsetImageArray)
        print("after data from the subsection to combine")
        print(dataFromTheSubsectionsToCombine.count)
        let mySummedSubesctions = SummingSubsections()
        mySummedSubesctions.imageHeight = imageHeight
        mySummedSubesctions.imageWidth = imageWidth
        mySummedSubesctions.numberOfStandardDeviationsAway = numberOfStandardDeviationsAway
        mySummedSubesctions.dataFromAllTheImagesToCombine = dataFromTheSubsectionsToCombine
        let summedSubsection = mySummedSubesctions.sumSubsectionOfImages()
        print(summedSubsection.count)
        dataFromAllTheStepsToCombine.append(summedSubsection)
        print(dataFromTheSubsectionsToCombine.count)
        weightingFactor.append(weight)
        
        
        
        
        
    }
    
        
        
    summedAllImageFloatArray = weightedSumOfImages(dataFromAllTheImagesToCombine: dataFromAllTheStepsToCombine, weights: weightingFactor)
        
        let dataRowBytes = imageWidth * 4
        
        var summedBuffer = try! vImage_Buffer.init(
            cgImage: returningCGImage(
                data: summedAllImageFloatArray,
                width: Int(imageWidth),
                height: Int(imageHeight),
                rowBytes: Int(dataRowBytes)
            )
        )
        
        
        let histogramcount = 1024
       // let histogramBin = histogram(dataMaxPixel: Pixel_F(data.max()!), dataMinPixel: Pixel_F(data.min()!), buffer: buffer, histogramcount: UInt32(histogramcount))
        let histogramBin = histogram(dataMaxPixel: Pixel_F(1.0), dataMinPixel: Pixel_F(0.0), buffer: summedBuffer, histogramcount: UInt32(histogramcount))
        
        let histogramValues = getHistogramLowerMaxUpperPixel(histogramBin: histogramBin, histogramcount: histogramcount)
        
        let histogramMin = histogramValues.0 / Float(histogramcount) * 1.0
        
        summedAllImageFloatArray = vDSP.add(-histogramMin, summedAllImageFloatArray)
        summedAllImageFloatArray = vDSP.clip(summedAllImageFloatArray, to: 0.0...1.0)

        
        summedDocument.imageHeight = UInt(imageHeight)
        summedDocument.imageWidth = UInt(imageWidth)
        
        summedDocument.rawFloatData = []
        summedDocument.rawFloatData.append(contentsOf: summedAllImageFloatArray)
        
//            print("newDocument summedFloatArray", newDocument.rawFloatData[33], newDocument.imageWidth, newDocument.imageHeight)
        
        let rowBytes :Int = Int(summedDocument.imageWidth) * MemoryLayout<Float>.size
        
        let starImage = returningCGImage(data: summedDocument.rawFloatData, width: Int(summedDocument.imageWidth), height: Int(summedDocument.imageHeight), rowBytes: rowBytes)
        
        
        summedDocument.starImage = starImage
        
        summedDocument.exportStarImage()
        
        summedImage = summedDocument.starImage
        
        
    }
    
    /// Just combines the pixels of each of the images, by mulitplying the "pixel contribution" to the floating array, which gives the summed images float array.
    /// - Parameters:
    ///   - dataFromAllTheImagesToCombine: <#dataFromAllTheImagesToCombine description#>
    ///   - weights: <#weights description#>
    /// - Returns: <#description#>
    func weightedSumOfImages(dataFromAllTheImagesToCombine: [[Float]], weights: [Float])->[Float]{
        
        print(imageWidth)
        print(imageHeight)
        
        var summedImagesFloatArray :[Float] = Array(repeating: 0.0, count: imageHeight*imageWidth)
        
                // Weighted Sum
        
        for pixel in stride(from: 0, to: imageHeight*imageWidth, by: 1){
 
 
             for arrayNumber in stride(from: 0, to: dataFromAllTheImagesToCombine.count, by: 1){
 
             //for floatingArray in dataFromAllTheImagesToCombine {
 
                 let floatingArray = dataFromAllTheImagesToCombine[arrayNumber]
                 let thePixelContribution = weights[arrayNumber]
 
 
                 summedImagesFloatArray[pixel] += floatingArray[pixel]*thePixelContribution
 
 
             }
            
            


        
        
    }
        
        var totalWeight = Float(0.0)
        
        for item in weights {
            
            
            totalWeight += Float(item)
        }
        
        summedImagesFloatArray = vDSP.multiply((1.0/totalWeight), summedImagesFloatArray)
        
        return summedImagesFloatArray
        
    }
    
    func extractFloatData(Data: ([FITSByte_F],vImage_Buffer,vImage_CGImageFormat)) -> ([Float]) {
        
        
        let floatData = returnRawFloat(RawData: Data)

            return floatData
        }

        
    
    /// Populates image field, first by removing previous image array, and then taking the selected document from the list, and printing the document. 
    func PopulateImageField(){
        
        imageArray.removeAll()
        
      //  imageArray.append(contentsOf: listOfDocuments.documentName)
        
        let starDocument = listOfDocuments.documentList[0]
        
        print(starDocument.imageHeight)
        
        let imageHeight = starDocument.imageHeight.wrappedValue
        //imageHeight = 2080
        //imageWidth = 3072
        
        print(imageHeight)
        
        print("Finding Stars")
        print(document)
        
    }
    
    
    @MainActor func updateImageParameters(width: Int, height: Int){
        
        imageWidth = width
        imageHeight = height
        
    }

}


struct AddImages_Previews: PreviewProvider {
    static var previews: some View {
        AddImages()
    }
}



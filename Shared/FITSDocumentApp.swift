//
//  FITSDocumentApp.swift
//  Shared
//
//  Created by Jeff Terry on 8/13/21.
//

import SwiftUI
import Combine

typealias DocumentBinding = Binding<FITSDocumentDocument>

@main
struct FITSDocumentApp: App {
    
    
    private let exportCommand = PassthroughSubject<Void, Never>()
    @StateObject var openDocuments = DocumentList()
    
    var body: some Scene {
//        DocumentGroup(newDocument: FITSDocumentDocument()) { file in
 //           ContentView(document: file.$document)
            
        DocumentGroup(viewing: FITSDocumentDocument.self) { file in
            ContentView(document: file.$document)
                .environmentObject(openDocuments)
                
                .onAppear(perform:{
                    openDocuments.documentList.append(file.$document)
                    openDocuments.documentName.append(file.document.text)
                })
                .onDisappear(perform:{
                    
                    if let index = openDocuments.documentName.firstIndex(of: file.document.text) {
                        openDocuments.documentList.remove(at: index)
                        openDocuments.documentName.remove(at: index)
                    }
                    
                    
                })
            //.focusedSceneValue(\.document, file.$document)
            //.focusedValue(\.document, file.$document)
            .onReceive(exportCommand) { _ in
                
                                //file.document.beginExport()
                file.document.exportPNG()
                }
        }
    
        .commands {
                    CommandMenu("FITS") {
                        Button("Export…") {
                            
                            exportCommand.send()
                        }
                        .keyboardShortcut("e", modifiers: .command)
                    }
        }
//        .commands {
//              CommandMenu("Stars") {
//                FindStars()
//
//                }
//            }
        
        Group{
        
                WindowGroup("Make Dark"){
                    
                    MakeDarkView()
                        .environmentObject(openDocuments)
                        .frame(maxWidth: .infinity)
                        //.frame(width: 700, height: 700)
                                    }
                .commands {
                    CommandMenu("Calibration") {
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "makeDark://my")!)
                        }, label: {
                            Text("Make Dark")
                        })
                        
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "subtractDark://my")!)
                        }, label: {
                            Text("Subtract Dark")
                        })
                        
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "makeFlat://my")!)
                        }, label: {
                            Text("Make Flat")
                        })
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "divideFlat://my")!)
                        }, label: {
                            Text("Divide Flat")
                        })
                        Button(action: {
                            NSWorkspace.shared.open(URL(string: "combineFlat://my")!)
                        }, label: {
                            Text("Combine Flat Image")
                        })
                    }
                }
                .handlesExternalEvents(matching: ["makeDark://"])
                
                WindowGroup("Make Flat") {
                   // FindStars(document: )
                    MakeFlatView( )
                        .environmentObject(openDocuments)
                        .frame(maxWidth: .infinity)
                        }
                .handlesExternalEvents(matching: ["makeFlat://"])
            
                WindowGroup("Combine Flat Image") {
                   // FindStars(document: )
                    MakeFlatImage( )
                        .environmentObject(openDocuments)
                        .frame(maxWidth: .infinity)
                        }
                .handlesExternalEvents(matching: ["combineFlat://"])
                
                WindowGroup("Subtract Dark"){
                    
                    SubtractDarkView()
                        .environmentObject(openDocuments)
                        .frame(maxWidth: .infinity)
                        //.frame(width: 700, height: 700)
                                    }
        //        .commands {
        //            CommandMenu("Subtract Dark") {
        //                Button(action: {
        //                    NSWorkspace.shared.open(URL(string: "subtractDark://my")!)
        //                }, label: {
        //                    Text("Subtract Dark")
        //                })
        //            }
        //        }
                .handlesExternalEvents(matching: ["subtractDark://"])
            
            
                WindowGroup("Divide Flat"){
                
                    DivideFlatView()
                        .environmentObject(openDocuments)
                        .frame(maxWidth: .infinity)
                    //.frame(width: 700, height: 700)
                                }
                .handlesExternalEvents(matching: ["divideFlat://"])
            
            
        }

                
//        WindowGroup("Tools") {
//                    Text("This is tool window")
//                        .frame(width: 200, height: 400)
//                }
//        .commands {
//            CommandMenu("Arithmetic") {
//                Button(action: {
//                    NSWorkspace.shared.open(URL(string: "myDark://my")!)
//                }, label: {
//                    Text("Make Dark")
//                })
//            }
//        }
//        .handlesExternalEvents(matching: ["myDark://my"])
        
        WindowGroup("Find Stars") {
           // FindStars(document: )
            FindStars( )
                .environmentObject(openDocuments)
                .frame(width: 200, height: 400)
                }
        
        .commands {
            CommandMenu("Find Stars") {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "findStars://my")!)
                }, label: {
                    Text("Find Stars")
                })
            }
        }
        .handlesExternalEvents(matching: ["findStars://"])
        
        WindowGroup("Color Images") {
           // FindStars(document: )
            ExtractColor( )
                .environmentObject(openDocuments)
                .frame(width: 400, height: 400)
                }
        
        .commands {
            CommandMenu("Extract Color") {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "extractColor://my")!)
                }, label: {
                    Text("Extract Color")
                })
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "combineColor://my")!)
                }, label: {
                    Text("Combine Color Images")
                })
            }
        }
        .handlesExternalEvents(matching: ["extractColor://"])
        
        WindowGroup("Combine Color Images") {
           // FindStars(document: )
            MakeColorImage( )
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
                }
        .handlesExternalEvents(matching: ["combineColor://"])
        
        WindowGroup("Mathematics") {
           // FindStars(document: )
            Mathematics( )
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
                }
        .commands {
            CommandMenu("Mathematics") {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "mathematics://my")!)
                }, label: {
                    Text("Rotate and Translate")
                })
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "addImages://my")!)
                }, label: {
                    Text("Add Images")
                })
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "multiplyByConstant://my")!)
                }, label: {
                    Text("Multiply By Constant")
                })
                
            }
        }
        .handlesExternalEvents(matching: ["mathematics://"])
        
        
        WindowGroup("AlignImages") {
           // FindStars(document: )
            AlignImages( )
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
                }
        .commands {
            CommandMenu("Align Images") {
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "align://my")!)
                }, label: {
                    Text("Align Images")
                })
                
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "alignColor://my")!)
                }, label: {
                    Text("Align Color Images")
                })
                
                
            }
        }
        .handlesExternalEvents(matching: ["align://"])
        
        WindowGroup("Multiply By Constant"){
            
            MultiplyByConstant()
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
        }
        .handlesExternalEvents(matching: ["multiplyByConstant://"])
        
        WindowGroup("Align Color Images") {
           // FindStars(document: )
            AlignColorImages( )
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
        }
        .handlesExternalEvents(matching: ["alignColor://"])
        
        WindowGroup("Add Images") {
           // FindStars(document: )
            AddImages( )
                .environmentObject(openDocuments)
                .frame(maxWidth: .infinity)
                }
        .handlesExternalEvents(matching: ["addImages://"])
        
        
        
        

        
    }
    
    
    
    
}

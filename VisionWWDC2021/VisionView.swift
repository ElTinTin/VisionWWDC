import SwiftUI
import VisionKit
import PDFKit
import WebKit

struct ScannerView: UIViewControllerRepresentable {
    private let completionHandler: ([UIImage]?) -> Void
    
    init(completion: @escaping ([UIImage]?) -> Void) {
        self.completionHandler = completion
    }
    
    typealias UIViewControllerType = VNDocumentCameraViewController
    
    func makeUIViewController(context: UIViewControllerRepresentableContext<ScannerView>) -> VNDocumentCameraViewController {
        let viewController = VNDocumentCameraViewController()
        viewController.delegate = context.coordinator
        return viewController
    }
    
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: UIViewControllerRepresentableContext<ScannerView>) {}
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(completion: completionHandler)
    }
    
    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        private var arrayOfScans: [UIImage] = []
        private let completionHandler: ([UIImage]?) -> Void
        
        init(completion: @escaping ([UIImage]?) -> Void) {
            self.completionHandler = completion
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            print("Document camera view controller did finish with ", scan)
            for index in 0 ..< scan.pageCount {
                let image = scan.imageOfPage(at: index)
                arrayOfScans.append(image)
            }
            completionHandler(arrayOfScans)
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            completionHandler(nil)
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document camera view controller did finish with error ", error)
            completionHandler(nil)
        }
    }
}

struct VisionView: View {
    private let buttonInsets = EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
    
    var body: some View {
        VStack(spacing: 32) {
            Text("Vision Kit Example")
            Button(action: openCamera) {
                Text("Scan").foregroundColor(.white)
            }.padding(buttonInsets)
                .background(Color.blue)
                .cornerRadius(3.0)
        }
        .sheet(isPresented: self.$isShowingScannerSheet) { self.makeScannerView() }
        .sheet(isPresented: self.$isShowingPDFSheet) { self.makePDF(images: self.images)}
    }
    
    @State private var isShowingScannerSheet = false
    @State private var isShowingPDFSheet = false
    @State private var images: [UIImage] = []
    
    private func openCamera() {
        isShowingScannerSheet = true
    }
    
    private func makeScannerView() -> ScannerView {
        ScannerView(completion: { images in
            if let images = images?.compactMap({ $0 }) {
                self.images = images
                self.isShowingPDFSheet = true
            }
            self.isShowingScannerSheet = false
        })
    }
    
    private func makePDF(images: [UIImage]) -> DriveWebViewRepresentedView {
        let pdfDocument = PDFDocument()
        for index in 0 ..< images.count {
            let pdfPage = PDFPage(image: images[index])
            pdfDocument.insert(pdfPage!, at: index)
        }
        
        let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let docURL = documentDirectory.appendingPathComponent("Scanned-Docs.pdf")
        let outputFileURL: URL = docURL
        
        let data = pdfDocument.dataRepresentation()
        try! data!.write(to: outputFileURL)
        
        return DriveWebViewRepresentedView(url: outputFileURL)
    }
}

struct DriveWebViewRepresentedView: UIViewRepresentable {
    var url: URL
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKPreferences()
        preferences.javaScriptEnabled = true
        
        let configuration = WKWebViewConfiguration()
        configuration.preferences = preferences
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }
}

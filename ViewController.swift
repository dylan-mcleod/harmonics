//
//  ViewController.swift
//  harmonic analyzer
//
//  Created by Dylan on 2/11/19.
//
//  OpenGL ES/GLKit setup code shamelessly taken from https://www.raywenderlich.com/5146-glkit-tutorial-for-ios-getting-started-with-opengl-es


import GLKit
import AVFoundation
struct Vertex {
    var x: GLfloat
    var y: GLfloat
    var z: GLfloat
    var r: GLfloat
    var g: GLfloat
    var b: GLfloat
    var a: GLfloat
}

var Vertices: [Vertex] = []

var Indices: [GLuint] = []

var numPoints = GLuint(100)

var fundamental = 200 // fundamental frequency
var sampleRate = fundamental * Int(numPoints) // samples per second to achieve desired fundamental
var numLoops = 8 // we'll play for 8 seconds

var audioBuf = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(commonFormat: (AVAudioCommonFormat.pcmFormatFloat32), sampleRate: Double(sampleRate), channels: AVAudioChannelCount(1), interleaved: false)!, frameCapacity: AVAudioFrameCount(sampleRate*numLoops))

var audioBuf_inUse = AVAudioPCMBuffer(pcmFormat: AVAudioFormat(commonFormat: (AVAudioCommonFormat.pcmFormatFloat32), sampleRate: Double(sampleRate), channels: AVAudioChannelCount(1), interleaved: false)!, frameCapacity: AVAudioFrameCount(sampleRate*numLoops))

var audioPlayer = AVAudioPlayerNode()

var audioData: [Float] = []

var audioEngine: AVAudioEngine?

extension Array {
    func size() -> Int {
        return MemoryLayout<Element>.stride * self.count
    }
}

private var ebo = GLuint()
private var vbo = GLuint()
private var vao = GLuint()

private var vertexAttribColor = GLuint()
private var vertexAttribPosition = GLuint()
private var vertexSize = MemoryLayout<Vertex>.stride
private var colorOffset = MemoryLayout<GLfloat>.stride * 3
private var colorOffsetPointer = UnsafeRawPointer(bitPattern: colorOffset)

class ViewController: GLKViewController {
    private var context: EAGLContext?
    private var effect = GLKBaseEffect()
    
    func initAudioData() {
        for i in 0...(Int(numPoints)) {
            audioData.append(Vertices[i].y);
        }
    }
    
    func updateAudioBuffer() {
        let sampleRate2 = Float(audioEngine!.mainMixerNode.outputFormat(forBus: 0).sampleRate)
        audioBuf = AVAudioPCMBuffer(pcmFormat: audioEngine!.mainMixerNode.outputFormat(forBus: 0), frameCapacity: AVAudioFrameCount(sampleRate*numLoops))
        for i in 0...(Int(numPoints)) {
            audioData[i] = Vertices[i].y*0.4+0.4;
        }
        for i in 0...(sampleRate*numLoops) {
            let t = audioData[i%(Int(numPoints)-1)]
            audioBuf!.floatChannelData![0][i] = t
        }
    
    print(Float(audioEngine!.mainMixerNode.outputFormat(forBus: 0).sampleRate))
    }
    
    func playAudio() {
        updateAudioBuffer()
        audioPlayer.scheduleBuffer(audioBuf!, at: nil, options:[])
    }
    
    
    private func fillVertAndIndexBufferData() {
        
        // indices
        for i in 0...numPoints {
            Indices.append(i)
        }
        
        // vertices (we'll give them all alpha 0)
        for i in 0...numPoints {
            Vertices.append(Vertex(x: (Float(i*2))/(Float(numPoints))-1.0, y: sin(3.1415926 * Float(i)/50.0), z: 0, r: 0, g: 0, b: 0, a: 1))
        }
        
    }
    private func setupGL() {
        // 1
        context = EAGLContext(api: .openGLES3)
        // 2
        EAGLContext.setCurrent(context)
        
        if let view = self.view as? GLKView, let context = context {
            // 3
            view.context = context
            // 4
            delegate = self
        }
        
        // 1
        vertexAttribColor = GLuint(GLKVertexAttrib.color.rawValue)
        // 2
        vertexAttribPosition = GLuint(GLKVertexAttrib.position.rawValue)
        vertexSize = MemoryLayout<Vertex>.stride
        colorOffset = MemoryLayout<GLfloat>.stride * 3
        // 5
        colorOffsetPointer = UnsafeRawPointer(bitPattern: colorOffset)
        
        // 1
        glGenVertexArraysOES(1, &vao)
        // 2
        glBindVertexArrayOES(vao)
        
        
        fillVertAndIndexBufferData()
        
        //   VERTEX BUFFER
        
        glGenBuffers(1, &vbo)
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER), // 1
            Vertices.size(),         // 2
            Vertices,                // 3
            GLenum(GL_STREAM_DRAW))  // 4
        
        //   ELEMENT BUFFER
        
        glGenBuffers(1, &ebo)
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)
        glBufferData(GLenum(GL_ELEMENT_ARRAY_BUFFER), Indices.size(), Indices, GLenum(GL_STATIC_DRAW))
        
        //   VERTEX ARRAY
        
        // This tutorial uses VAOs properly, which is a bit weird.
        // Frankly I just make a single VAO and ignore its existence.
        // But when in rome, you do as the romans do.
        glEnableVertexAttribArray(vertexAttribPosition)
        glVertexAttribPointer(vertexAttribPosition,       // 1
            3,                          // 2
            GLenum(GL_FLOAT),           // 3
            GLboolean(UInt8(GL_FALSE)), // 4
            GLsizei(vertexSize),        // 5
            nil)                        // 6
        
        glEnableVertexAttribArray(vertexAttribColor)
        glVertexAttribPointer(vertexAttribColor,
                              4,
                              GLenum(GL_FLOAT),
                              GLboolean(UInt8(GL_FALSE)),
                              GLsizei(vertexSize),
                              colorOffsetPointer)
    }
    
    
    
    
    
    var fingers = [UITouch?](repeating: nil, count:5)
    var prevTouches = [CGPoint](repeating:CGPoint(x:0,y:0), count:5)
    
    func handleTouch(prevTouch: CGPoint,  thisTouch: CGPoint) {
        
        let x1 = (prevTouch.x - self.view.frame.minX)/self.view.frame.width
        let y1 = 1.0-2.0*(prevTouch.y - self.view.frame.minY)/self.view.frame.height
        
        let x2 = (thisTouch.x - self.view.frame.minX)/self.view.frame.width
        let y2 = 1.0-2.0*(thisTouch.y - self.view.frame.minY)/self.view.frame.height
        
        var index1 = Int(Float(numPoints) * Float(x1))
        index1 = max(0,index1)
        index1 = min(Int(numPoints)-1,index1);
        var index2 = Int(Float(numPoints) * Float(x2))
        index2 = max(0,index2)
        index2 = min(Int(numPoints)-1,index2);
        
        let dy = y2-y1;
        var yprime = dy/CGFloat(index2-index1);
        
        var y = y1;
        if(index2 < index1) {
            let temp = index2;
            index2 = index1;
            index1 = temp;
            y = y2;
            yprime = -yprime;
        }
        for i in index1...index2 {
            
            Vertices[i].y = Float(y);
            
            y += yprime
        }
        
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        for touch in touches{
            for (index,finger)  in fingers.enumerated() {
                if finger == nil {
                    handleTouch(prevTouch: touch.preciseLocation(in: self.view), thisTouch: touch.preciseLocation(in: self.view))
                    prevTouches[index] = touch.preciseLocation(in: self.view)
                    fingers[index] = touch
                    break
                }
            }
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        for touch in touches {
            for (index,finger) in fingers.enumerated() {
                if let finger = finger, finger == touch {
                    handleTouch(prevTouch: prevTouches[index], thisTouch: touch.preciseLocation(in: self.view))
                    prevTouches[index] = touch.preciseLocation(in: self.view)
                    break
                }
            }
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        for touch in touches {
            for (index,finger) in fingers.enumerated() {
                if let finger = finger, finger == touch {
                    handleTouch(prevTouch: prevTouches[index], thisTouch: touch.preciseLocation(in: self.view))
                    prevTouches[index] = touch.preciseLocation(in: self.view)
                    fingers[index] = nil
                    break
                }
            }
        }
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        //if touches == nil { return }
        touchesEnded(touches, with: event)
    }
    
    private func tearDownGL() {
        EAGLContext.setCurrent(context)
        
        glDeleteBuffers(1, &vao)
        glDeleteBuffers(1, &vbo)
        glDeleteBuffers(1, &ebo)
        
        EAGLContext.setCurrent(nil)
        
        context = nil
    }
    deinit {
        tearDownGL()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(AVAudioSession.Category.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        }
        catch {
            print("bad juju ahead")
        }
        print(session.isOtherAudioPlaying)
        audioEngine = AVAudioEngine()
        audioPlayer = AVAudioPlayerNode()
        audioEngine!.attach(audioPlayer)
        let sampleRate2 = Float(audioEngine!.mainMixerNode.outputFormat(forBus: 0).sampleRate)
        audioEngine!.connect(audioPlayer, to:(audioEngine!.mainMixerNode), format: audioEngine!.mainMixerNode.outputFormat(forBus: 0))
        do {
            try audioEngine!.start()
        }
        catch {
            print("Audio Engine didn't start")
        }
        
        setupGL()
        initAudioData()
        
        audioPlayer.play()
        playAudio()
    }
    
    private var frameN = 0
    
    override func glkView(_ view: GLKView, drawIn rect: CGRect) {
        
        frameN += 1
        
        if(frameN%300 == 0) {
            playAudio()
        }
        
        
        // clear buffers
        // 1
        glClearColor(0, 1, 0, 1.0)
        // 2
        glClear(GLbitfield(GL_COLOR_BUFFER_BIT))
        
        // draw vertices
        effect.prepareToDraw()
        
        // bind the respective vao instead of respecifying glVertexAttribPointers -- wild.
        glBindVertexArrayOES(vao);
        
        // Stream data just before drawing
        glBindBuffer(GLenum(GL_ARRAY_BUFFER), vbo)
        glBufferData(GLenum(GL_ARRAY_BUFFER), Vertices.size(), nil, GLenum(GL_STREAM_DRAW))
        glBufferData(GLenum(GL_ARRAY_BUFFER), Vertices.size(), Vertices, GLenum(GL_STREAM_DRAW))
        
        // Orphan the buffer
        
        // G
        
        
        glBindBuffer(GLenum(GL_ELEMENT_ARRAY_BUFFER), ebo)
        glDrawElements(GLenum(GL_LINE_STRIP),     // 1
            GLsizei(Indices.count),   // 2
            GLenum(GL_UNSIGNED_INT), // 3
            nil)                      // 4
    }
}

extension ViewController: GLKViewControllerDelegate {
    func glkViewControllerUpdate(_ controller: GLKViewController) {
        
    }
}




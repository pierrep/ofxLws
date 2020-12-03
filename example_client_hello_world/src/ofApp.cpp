#include "ofApp.h"

//--------------------------------------------------------------
void ofApp::setup(){
    ofBackground(0);
    ofSetLogLevel(OF_LOG_NOTICE);
    // basic connection:
    client.connect("echo.websocket.org");
    // OR optionally use SSL
     //client.connect("echo.websocket.org", true);
    
    // 1 - get default options
//    ofxLibwebsockets::ClientOptions options = ofxLibwebsockets::defaultClientOptions();
    
//    // 2 - set basic params
//    options.host = "echo.websocket.org";
    
//    // advanced: set keep-alive timeouts for events like
//    // loss of internet
    
//    // 3 - set keep alive params
//    // BIG GOTCHA: on BSD systems, e.g. Mac OS X, these time params are system-wide
//    // ...so ka_time just says "check if alive when you want" instead of "check if
//    // alive after X seconds"
//    options.ka_time     = 1;
//    options.ka_probes   = 1;
//    options.ka_interval = 1;
    
//    // 4 - connect
//    client.connect(options);
    
    client.addListener(this);
    ofSetFrameRate(60);

}

//--------------------------------------------------------------
void ofApp::update(){
}

//--------------------------------------------------------------
void ofApp::draw(){
    ofDrawBitmapString("Type anywhere to send 'hello' to your server\nCheck the console for output!", 10,20);
    ofDrawBitmapString(client.isConnected() ? "Client is connected" : "Client disconnected :(", 10,50);
}

//--------------------------------------------------------------
void ofApp::onConnect( ofxLibwebsockets::Event& args ){
    ofLogNotice() << "Connected to: "<< args.conn.getClientIP();
}

//--------------------------------------------------------------
void ofApp::onClose( ofxLibwebsockets::Event& args ){
    ofLogVerbose() << "onClose";
}

//--------------------------------------------------------------
void ofApp::onIdle( ofxLibwebsockets::Event& args ){
    ofLogVerbose() << "onIdle";
}

//--------------------------------------------------------------
void ofApp::onMessage( ofxLibwebsockets::Event& args ){
    ofLogNotice() << "Got message: " << args.message;
}

//--------------------------------------------------------------
void ofApp::onBroadcast( ofxLibwebsockets::Event& args ){
    ofLogNotice() << "Got broadcast: " <<args.message;
}

//--------------------------------------------------------------
void ofApp::keyPressed(int key){
    
    client.send("Hello");
    ofLogNotice() << "Sending: Hello";
}

//--------------------------------------------------------------
void ofApp::keyReleased(int key){
    
}

//--------------------------------------------------------------
void ofApp::mouseMoved(int x, int y ){
    
}

//--------------------------------------------------------------
void ofApp::mouseDragged(int x, int y, int button){
    
}

//--------------------------------------------------------------
void ofApp::mousePressed(int x, int y, int button){

}

//--------------------------------------------------------------
void ofApp::mouseReleased(int x, int y, int button){
    
}

//--------------------------------------------------------------
void ofApp::windowResized(int w, int h){
    
}

//--------------------------------------------------------------
void ofApp::gotMessage(ofMessage msg){
    
}

//--------------------------------------------------------------
void ofApp::dragEvent(ofDragInfo dragInfo){
    
}

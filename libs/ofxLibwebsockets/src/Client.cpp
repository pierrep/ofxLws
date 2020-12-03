//
//  Client.cpp
//  ofxLibwebsockets
//
//  Created by Brett Renfer on 4/11/12. 
//

#include "ofxLibwebsockets/Client.h"
#include "ofxLibwebsockets/Util.h"

namespace ofxLibwebsockets {

   ClientOptions defaultClientOptions(){
       ClientOptions opts;
       opts.host      = "localhost";
       opts.port      = 80;
       opts.bUseSSL   = false;
       opts.path   = "/";
       opts.protocol  = "default";
       opts.version   = -1;     //use latest version

       // Note, turning this on has been seen to cause an EXC_BAD_ACCESS error
       // when calling lws_service() in threadedFunction(). If you're
       // having issues, try raising the reconnect interval, or not using this
       // reconnect option. Use at your own risk!
       opts.reconnect = true;
       opts.reconnectInterval = 1000;

       opts.ka_time      = 0;
       opts.ka_probes    = 0;
       opts.ka_interval  = 10;
       return opts;
   };

    Client::Client(){
        context = NULL;
        connection = NULL;
        waitMillis = 1;
        reactors.push_back(this);
        
        defaultOptions = defaultClientOptions();

        ofAddListener( ofEvents().update, this, &Client::update);
        ofAddListener( clientProtocol.oncloseEvent, this, &Client::onClose);
    }

    
    //--------------------------------------------------------------
    Client::~Client(){
        ofLogVerbose() << "Client destructor...";
        close();
        ofRemoveListener( ofEvents().update, this, &Client::update);
    }
    
    //--------------------------------------------------------------
    bool Client::connect ( string _address, bool bUseSSL ){
        defaultOptions.host     = _address;
        defaultOptions.bUseSSL  = bUseSSL;
        defaultOptions.port     = (bUseSSL ? 443 : 80);
        
        return connect( defaultOptions );
    }

    //--------------------------------------------------------------
    bool Client::connect ( string _address, int _port, bool bUseSSL ){
        defaultOptions.host     = _address;
        defaultOptions.port     = _port;
        defaultOptions.bUseSSL  = bUseSSL;
        
        return connect( defaultOptions );
    }

    //--------------------------------------------------------------
    bool Client::connect ( ClientOptions options ){
        address = options.host;
        port    = options.port;  
        path = options.path;
        defaultOptions = options;
        bShouldReconnect = defaultOptions.reconnect;

		/*
			enum lws_log_levels {
			LLL_ERR = 1 << 0,
			LLL_WARN = 1 << 1,
			LLL_NOTICE = 1 << 2,
			LLL_INFO = 1 << 3,
			LLL_DEBUG = 1 << 4,
			LLL_PARSER = 1 << 5,
			LLL_HEADER = 1 << 6,
			LLL_EXT = 1 << 7,
			LLL_CLIENT = 1 << 8,
			LLL_LATENCY = 1 << 9,
			LLL_COUNT = 10 
		};
		*/
        lws_set_log_level(LLL_ERR|LLL_WARN, NULL);
        //lws_set_log_level(LLL_INFO|LLL_ERR|LLL_WARN|LLL_NOTICE|LLL_HEADER|LLL_CLIENT, nullptr);

        // set up default protocols
        struct lws_protocols null_protocol = { NULL, NULL, 0 };
        
        // setup the default protocol (the one that works when you do addListener())
        registerProtocol( options.protocol, clientProtocol );  
        
        lws_protocols.clear();
        for (int i=0; i<protocols.size(); ++i)
        {
            struct lws_protocols lws_protocol = {
                ( protocols[i].first == "NULL" ? NULL : protocols[i].first.c_str() ),
                lws_client_callback,
                protocols[i].second->rx_buffer_size,
                protocols[i].second->rx_buffer_size
            };
            lws_protocols.push_back(lws_protocol);
        }
        lws_protocols.push_back(null_protocol);

        struct lws_context_creation_info info;
        memset(&info, 0, sizeof info);
        info.port = CONTEXT_PORT_NO_LISTEN;
        info.protocols = &lws_protocols[0];
        info.gid = -1;
        info.uid = -1;
        
        if ( options.ka_time != 0 ){
            ofLogVerbose()<<"[ofxLibwebsockets] Setting timeout "<<options.ka_time;
            info.ka_time = options.ka_time;
            info.ka_probes = options.ka_probes;
            info.ka_interval = options.ka_interval;
        }

        context = lws_create_context(&info);

        if (context == NULL){
            ofLogError() << "[ofxLibwebsockets] libwebsocket init failed";
            return false;
        } else {
            ofLogVerbose() << "[ofxLibwebsockets] libwebsocket init success";
            
            string host = options.host +":"+ ofToString( options.port );
            
            struct lws_client_connect_info ccinfo;
            memset(&ccinfo, 0, sizeof ccinfo);
            ccinfo.context = context;
            ccinfo.address = options.host.c_str();            
            ccinfo.port = options.port;
            ccinfo.ssl_connection = options.bUseSSL ? 2 : 0;
            ccinfo.path = options.path.c_str();
            ccinfo.host = options.host.c_str();
            ccinfo.origin = options.host.c_str();
            //ccinfo.host = host.c_str();
            //ccinfo.origin = host.c_str();
            ccinfo.protocol = NULL;
            ccinfo.method = NULL;
            ccinfo.pwsi = &lwsconnection;

            // register with or without a protocol
            if ( options.protocol != "NULL"){
                ccinfo.protocol = options.protocol.c_str();
            }

            ofLogVerbose() << "ccinfo.address = " << ccinfo.address;
            ofLogVerbose() << "ccinfo.port = " << ccinfo.port;
            ofLogVerbose() << "ccinfo.ssl_connection = " <<  ccinfo.ssl_connection;
            ofLogVerbose() << "ccinfo.path = " << ccinfo.path;
            ofLogVerbose() << "ccinfo.host = " << ccinfo.host;
            ofLogVerbose() << "ccinfo.origin = " << ccinfo.origin;
            ofLogVerbose() << "ccinfo.protocol = " << ccinfo.protocol;

            lwsconnection = lws_client_connect_via_info(&ccinfo);
                        
            if ( lwsconnection == NULL ){
                ofLogError("ofxLibwebsockets") << "Client connection failed";
                return false;
            } else {
                connection = new Connection( (Reactor*) &context, &clientProtocol );
                connection->ws = lwsconnection;                
                
                ofLogNotice("Client") << "Initiating connection to "  << ccinfo.address << " port: " << ccinfo.port << " path: "+options.path+" SSL: "+ofToString(options.bUseSSL);

                startThread();
                return true;
            }


        }
    }
    
    //--------------------------------------------------------------
    bool Client::isConnected(){
        if ( connection == NULL || lwsconnection == NULL ){
            return false;
        } else {
            // we need a better boolean switch...
            // for now, connections vector is only populated
            // with valid connections
            return connections.size() > 0;
        }
    }

    //--------------------------------------------------------------
    void Client::close(){
        ofLogNotice("Client") << "Closing...";

        // Self-initiated call to close() means we shouldn't try to reconnect
        bShouldReconnect = false;

        if (isThreadRunning()){
            stopThread();
            ofSleepMillis(10);
            waitForThread(false,5000);
            ofLogNotice("Server") << "Thread stopped...";
        }

        if ( context != NULL ){
            lws_context_destroy( context );
            context = NULL;        
            lwsconnection = NULL;
        }
		if ( connection != NULL){
            delete connection;
			connection = NULL;                
		}
    }


    //--------------------------------------------------------------
    void Client::onClose( Event& args ){

		lastReconnectTime = ofGetElapsedTimeMillis();
    }

    //--------------------------------------------------------------
    void Client::send( string message ){
        if ( connection != NULL){
            connection->send( message );
        }
    }
    
    //--------------------------------------------------------------
    void Client::sendBinary( ofBuffer & buffer ){
        if ( connection != NULL){
            connection->sendBinary(buffer);
        }
    }
    
    //--------------------------------------------------------------
    void Client::sendBinary( unsigned char * data, int size ){
        if ( connection != NULL){
            connection->sendBinary(data,size);
        }
    }
    
    //--------------------------------------------------------------
    void Client::sendBinary( char * data, int size ){
        if ( connection != NULL){
            connection->sendBinary(data,size);
        }
    }

    //--------------------------------------------------------------
    void Client::update(ofEventArgs& args) {
        if (!isConnected() && bShouldReconnect) {
            uint64_t now = ofGetElapsedTimeMillis();
            if (now - lastReconnectTime > defaultOptions.reconnectInterval) {
                lastReconnectTime = now;
                connect( defaultOptions );
            }
        }
    }

    //--------------------------------------------------------------
    void Client::threadedFunction(){
        while ( isThreadRunning() ){
            for (int i=0; i<protocols.size(); ++i){
                if (protocols[i].second != NULL){
                    //lock();
                    protocols[i].second->execute();
                    //unlock();
                }
            }
            if (context != NULL && lwsconnection != NULL){
                connection->update();
                
                if (lock())
                {
                    int n = lws_service(context, -1);
                    unlock();
                }
                ofSleepMillis(1);
            }
        }
    }
}

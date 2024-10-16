import os
import time
import socket

import mitmproxy.http


deviceip1 = "172.19.193.233"
deviceip2 = "172.19.194.107"
deviceip3 = "172.19.193.18"

class Counter:
    def __init__(self):
        self.sessions = {}  
        self.request_count = 0  
        self.response_count = 0  
        self.error_log_file_all = ""  
        self.current_dir = os.path.dirname(os.path.abspath(__file__))
        self.log_dir = os.path.join(self.current_dir, "log")
    
    def load(self, loader):
        os.makedirs(self.log_dir, exist_ok=True)
        
        error_log_file_name = f"{time.strftime('%Y%m%d')}_error_log.txt"
        self.error_log_file_all = os.path.join(self.log_dir, error_log_file_name)
    
    def request(self, flow: mitmproxy.http.HTTPFlow):
        client_ip = flow.client_conn.peername[0]
        deviceid = ""
        if client_ip == deviceip1:
            deviceid = "device1"
        elif client_ip == deviceip2:
            deviceid = "device2"
        elif client_ip == deviceip3:
            deviceid = "device3"
        
        flow.metadata["request_timestamp"] = time.time()
        
        if "session_id" not in flow.metadata:
            session_id = self.get_session_id(deviceid)
            self.sessions[flow] = self.create_session_dir(session_id,deviceid)
            flow.metadata["session_id"] = session_id
        
        session_dir = self.sessions[flow]
        
       
        request_body_file = os.path.join(session_dir, "request_body.txt")
        with open(request_body_file, mode="wb") as f:
            if flow.request.content:
                try:
                    f.write(flow.request.content)
                except UnicodeDecodeError as e:
                    self.log_error(session_dir, flow, "request", str(e))

       
        headers_file = os.path.join(session_dir, "headers.txt")
        with open(headers_file, mode="w", encoding="UTF-8") as f:
            f.write(f"{flow.request.method} {flow.request.url}\n")
            for name, value in flow.request.headers.items():
                f.write(f"{name}: {value}\n")
            f.write("\n\n")
        
       
        self.request_count += 1

    def response(self, flow: mitmproxy.http.HTTPFlow):
        session_dir = self.sessions.get(flow, None)
        if session_dir is None:
            return
        
        
        flow.metadata["response_timestamp"] = time.time()
        
        # Save response body
        response_body_file = os.path.join(session_dir, "response_body.txt")
        with open(response_body_file, mode="wb") as f:
            if flow.response.content:
                try:
                    f.write(flow.response.content)
                except UnicodeDecodeError as e:
                    self.log_error(session_dir, flow, "response", str(e))

        # Append response headers to existing headers file
        headers_file = os.path.join(session_dir, "headers.txt")
        with open(headers_file, mode="a", encoding="UTF-8") as f:
            f.write(f"\n\n{flow.response.http_version} {flow.response.status_code} {flow.response.reason}\n")
            for name, value in flow.response.headers.items():
                f.write(f"{name}: {value}\n")

	
        client_address = flow.client_conn.address
        client_address_str = f"{client_address[0]}:{client_address[1]}"
        
        server_address = flow.server_conn.address
        server_address_str = f"{server_address[0]}:{server_address[1]}"
        server_resolved_address = socket.gethostbyname(server_address[0]) 

       
        metadata_file = os.path.join(session_dir, "metadata.txt")
        with open(metadata_file, mode="w", encoding="UTF-8") as f:
            f.write("Client Connection\n")
            f.write("Address:\t" + client_address_str + "\n\n")
            f.write("Server Connection\n")
            f.write("Address:\t" + server_address_str + "\n")
            f.write("Resolved address:\t" + server_resolved_address + "\n\n")
        
        
        self.response_count += 1

    def log_error(self, session_dir, flow, flow_type, error_message):
        error_log_file = os.path.join(session_dir, "error_log.txt")
        with open(error_log_file, mode="a", encoding="UTF-8") as f:
            f.write(f"{time.strftime('%H:%M:%S')}  {flow.metadata['session_id']}  {flow_type}\n")
            f.write(f"{error_message}\n\n")
        
        with open(self.error_log_file_all, mode="a", encoding="UTF-8") as f:
            f.write(f"{time.strftime('%H:%M:%S')}  {flow.metadata['session_id']}  {flow_type}\n")
            f.write(f"{error_message}\n\n")

    def get_session_id(self,deviceid):
        logpath = os.path.join(self.log_dir,deviceid)
        session_folders = os.listdir(logpath)
        session_id = len(session_folders) + 1
        
        session_dir = os.path.join(logpath, str(session_id))
        os.makedirs(session_dir, exist_ok=True)
        
        return session_id

    def create_session_dir(self, session_id,deviceid):
        session_dir = os.path.join(self.log_dir, deviceid, str(session_id))
        os.makedirs(session_dir, exist_ok=True)
        
        return session_dir


addons = [
    Counter()
]
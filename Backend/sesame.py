from sesame_ai import SesameAI, SesameWebSocket, TokenManager
import pyaudio
import threading
import time
import numpy as np

# Get authentication token using TokenManager
api_client = SesameAI()
token_manager = TokenManager(api_client, token_file="token.json")
id_token = token_manager.get_valid_token()

# Connect to WebSocket (choose character: "Miles" or "Maya")
ws = SesameWebSocket(id_token=id_token, character="Maya")

# Set up connection callbacks
def on_connect():
    print("Connected to SesameAI!")

def on_disconnect():
    print("Disconnected from SesameAI")

ws.set_connect_callback(on_connect)
ws.set_disconnect_callback(on_disconnect)

# Connect to the server
ws.connect()

# Audio settings
CHUNK = 1024
FORMAT = pyaudio.paInt16
CHANNELS = 1
RATE = 16000

# Initialize PyAudio
p = pyaudio.PyAudio()

# Open microphone stream
mic_stream = p.open(format=FORMAT,
                    channels=CHANNELS,
                    rate=RATE,
                    input=True,
                    frames_per_buffer=CHUNK)

# Open speaker stream (using server's sample rate)
speaker_stream = p.open(format=FORMAT,
                        channels=CHANNELS,
                        rate=ws.server_sample_rate,
                        output=True)

# Function to capture and send microphone audio
def capture_microphone():
    print("Microphone capture started...")
    try:
        while True:
            if ws.is_connected():
                data = mic_stream.read(CHUNK, exception_on_overflow=False)
                ws.send_audio_data(data)
            else:
                time.sleep(0.1)
    except KeyboardInterrupt:
        print("Microphone capture stopped")

# Function to play received audio
def play_audio():
    print("Audio playback started...")
    try:
        while True:
            audio_chunk = ws.get_next_audio_chunk(timeout=0.01)
            if audio_chunk:
                speaker_stream.write(audio_chunk)
    except KeyboardInterrupt:
        print("Audio playback stopped")

# Start audio threads
mic_thread = threading.Thread(target=capture_microphone)
mic_thread.daemon = True
mic_thread.start()

playback_thread = threading.Thread(target=play_audio)
playback_thread.daemon = True
playback_thread.start()

# Keep the main thread alive
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    print("Disconnecting...")
    ws.disconnect()
    mic_stream.stop_stream()
    mic_stream.close()
    speaker_stream.stop_stream()
    speaker_stream.close()
    p.terminate()
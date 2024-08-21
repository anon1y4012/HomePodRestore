import os
import subprocess
import threading
import customtkinter as ctk
from tkinter import filedialog
from datetime import datetime
import pty

# Paths to tools and modules
script_path = os.path.join(os.path.dirname(__file__), "makeipsw.sh")
fwkeydb_tool_path = os.path.join(os.path.dirname(__file__), "fwkeydb_tools-1.0")

# Add the tools directory to sys.path
# sys.path.insert(0, fwkeydb_tool_path)

# Comment out or remove the imports related to key generation
# import coreFWKEYDBLib
# import decryptFirmwareBatch
# import irecv_device
# import makeBuildManifestFromRestoreplist
# import moduleDecryptor
# import verifyKeyfileBatch

# Comment out the initialization of decryption modules
# moduleDecryptor.init()

processes = []

# Comment out the key generation function
# def generate_keys_for_device(device_model):
#     command = f"./listURLsForDevice.sh {device_model}"
#     process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE)
#     firmware_urls = process.stdout.read().decode().splitlines()
# 
#     for url in firmware_urls:
#         decryptFirmwareBatch.processUrl(url)
#     
#     output_text.insert(ctk.END, "Key generation completed.\n")
#     output_text.yview(ctk.END)

# Comment out the function to start key generation
# def start_generate_keys():
#     device_model = device_model_var.get()  # Example: 'AudioAccessory1,1' for HomePod 1st gen
#     threading.Thread(target=generate_keys_for_device, args=(device_model,)).start()

# Comment out the browse key output file function
# def browse_key_output_file():
#     file = filedialog.asksaveasfilename(defaultextension=".zip", filetypes=[("ZIP files", "*.zip")])
#     if file:
#         keygen_output_var.set(file)

# Initialize the customtkinter library and set the theme
ctk.set_appearance_mode("Dark")
ctk.set_default_color_theme("dark-blue")

dependencies = [
    "libimobiledevice-glue",
    "libimobiledevice",
    "libirecovery",
    "idevicerestore",
    "gaster",
    "ldid-procursus",
    "tsschecker",
    "img4tool",
    "ra1nsn0w"
]

missing_deps = []

def check_dependency(dep):
    try:
        subprocess.run(["brew", "list", dep], check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        return True
    except subprocess.CalledProcessError:
        return False

def verify_dependencies_async():
    output_text.insert(ctk.END, "Verifying dependencies...\n")
    missing_deps.clear()
    for dep in dependencies:
        output_text.insert(ctk.END, f"Checking {dep}...\n")
        if not check_dependency(dep):
            missing_deps.append(dep)
            output_text.insert(ctk.END, f"{dep} is missing.\n")
        else:
            output_text.insert(ctk.END, f"{dep} is installed.\n")
        output_text.yview(ctk.END)
    
    if missing_deps:
        output_text.insert(ctk.END, f"The following dependencies are missing: {', '.join(missing_deps)}\n")
        output_text.insert(ctk.END, "Please click 'Install Dependencies' to install missing packages.\n")
    else:
        output_text.insert(ctk.END, "All dependencies are installed.\n")
    output_text.yview(ctk.END)

def start_verify_dependencies():
    threading.Thread(target=verify_dependencies_async).start()
    
def start_install_dependencies():
    threading.Thread(target=install_dependencies_async).start()

def install_dependencies_async():
    if missing_deps:
        output_text.insert(ctk.END, f"Installing missing dependencies: {', '.join(missing_deps)}...\n")
        for dep in missing_deps:
            output_text.insert(ctk.END, f"Installing {dep}...\n")
            process = subprocess.Popen(["brew", "install", "--HEAD", dep], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            for line in process.stdout:
                output_text.insert(ctk.END, line.decode('utf-8'))
                output_text.yview(ctk.END)
            for line in process.stderr:
                output_text.insert(ctk.END, line.decode('utf-8'))
                output_text.yview(ctk.END)
            process.wait()
        output_text.insert(ctk.END, "Dependency installation complete. Please verify dependencies again.\n")
    else:
        output_text.insert(ctk.END, "No missing dependencies to install.\n")
    output_text.yview(ctk.END)

def run_script_thread():
    ota_file = ota_var.get()
    ipsw_file = ipsw_var.get()
    keys_file = keys_var.get()
    output_file = output_var.get()

    command = f"{script_path} \"{ota_file}\" \"{ipsw_file}\" \"{output_file}\" \"{keys_file}\""
    
    log_file_path = os.path.join(os.path.dirname(__file__), f"flash_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    
    with open(log_file_path, "w") as log:
        process = subprocess.Popen(command, shell=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        processes.append(process)  # Track this process
        for line in process.stdout:
            decoded_line = line.decode('utf-8')
            log.write(decoded_line)
            
            output_text.insert(ctk.END, decoded_line)
            output_text.yview(ctk.END)
            if int(output_text.index('end-1c').split('.')[0]) > 50:
                output_text.delete(1.0, 2.0)
            
        for line in process.stderr:
            decoded_line = line.decode('utf-8')
            log.write(decoded_line)
            
            output_text.insert(ctk.END, decoded_line)
            output_text.yview(ctk.END)
            if int(output_text.index('end-1c').split('.')[0]) > 50:
                output_text.delete(1.0, 2.0)

def run_script():
    threading.Thread(target=run_script_thread).start()

def flash_ipsw_thread():
    ipsw_file = flash_ipsw_var.get()
    command = f"gaster pwn && gaster reset && idevicerestore -d -e {ipsw_file}"

    log_file_path = os.path.join(os.path.dirname(__file__), f"flash_log_{datetime.now().strftime('%Y%m%d_%H%M%S')}.txt")
    
    with open(log_file_path, 'w') as log_file:
        master, slave = pty.openpty()

        process = subprocess.Popen(command, stdout=slave, stderr=slave, shell=True, text=True, bufsize=1, universal_newlines=True)
        processes.append(process)  # Track this process

        while True:
            output = os.read(master, 1024).decode()
            if not output and process.poll() is not None:
                break
            if output:
                log_file.write(output)
                
                output_text.insert(ctk.END, output)
                output_text.yview(ctk.END)
                if int(output_text.index('end-1c').split('.')[0]) > 50:
                    output_text.delete(1.0, 2.0)

        process.wait()

    output_text.insert(ctk.END, "Flashing process completed.\n")
    output_text.yview(ctk.END)

def flash_ipsw():
    threading.Thread(target=flash_ipsw_thread).start()

def browse_file(var, filetypes):
    file = filedialog.askopenfilename(filetypes=filetypes)
    if file:
        var.set(file)

def stop_all_processes():
    output_text.insert(ctk.END, "Stopping all processes...\n")
    for process in processes:
        if process.poll() is None:  # If the process is still running
            process.terminate()
            output_text.insert(ctk.END, f"Process {process.pid} terminated.\n")
    output_text.yview(ctk.END)

# Initialize the main window
root = ctk.CTk()
root.title("HomePod Restore Tool")

# Variables for file paths
ota_var = ctk.StringVar()
ipsw_var = ctk.StringVar()
keys_var = ctk.StringVar()
output_var = ctk.StringVar()
flash_ipsw_var = ctk.StringVar()
keygen_output_var = ctk.StringVar()

# Set default output files
output_var.set(os.path.join(os.path.expanduser("~/Downloads"), "homepodrestore.ipsw"))
keygen_output_var.set(os.path.join(os.path.expanduser("~/Downloads"), "homepodkeys.zip"))

# Set up row and column weights for the root window
root.grid_rowconfigure(0, weight=0)  # Dependencies row doesn't need to expand
root.grid_rowconfigure(1, weight=0)  # Create IPSW section doesn't need to expand
root.grid_rowconfigure(2, weight=0)  # Flash IPSW section doesn't need to expand
root.grid_rowconfigure(3, weight=0)  # Key Generation section doesn't need to expand
root.grid_rowconfigure(4, weight=1)  # Output log should expand
root.grid_columnconfigure(0, weight=1)  # Allow columns to expand

# Dependency check section
dependencies_frame = ctk.CTkFrame(root)
dependencies_frame.grid(row=0, column=0, columnspan=3, padx=10, pady=10, sticky="ew")

# Centering the Verify and Install Dependencies buttons
button_frame = ctk.CTkFrame(dependencies_frame)
button_frame.pack(anchor="center")

verify_button = ctk.CTkButton(button_frame, text="Verify Dependencies", command=start_verify_dependencies)
verify_button.pack(side=ctk.LEFT, padx=5, pady=5, expand=True)

install_button = ctk.CTkButton(button_frame, text="Install Dependencies", command=start_install_dependencies)
install_button.pack(side=ctk.LEFT, padx=5, pady=5, expand=True)

# Create IPSW section
create_ipsw_frame = ctk.CTkFrame(root)
create_ipsw_frame.grid(row=1, column=0, columnspan=3, padx=10, pady=10, sticky="ew")
create_ipsw_frame.grid_columnconfigure(1, weight=1)

ctk.CTkLabel(create_ipsw_frame, text="OTA File:").grid(row=0, column=0, sticky="e")
ctk.CTkEntry(create_ipsw_frame, textvariable=ota_var, width=300).grid(row=0, column=1, padx=5, pady=5)
ctk.CTkButton(create_ipsw_frame, text="Browse...", command=lambda: browse_file(ota_var, [("ZIP files", "*.zip")])).grid(row=0, column=2)

ctk.CTkLabel(create_ipsw_frame, text="IPSW File:").grid(row=1, column=0, sticky="e")
ctk.CTkEntry(create_ipsw_frame, textvariable=ipsw_var, width=300).grid(row=1, column=1, padx=5, pady=5)
ctk.CTkButton(create_ipsw_frame, text="Browse...", command=lambda: browse_file(ipsw_var, [("IPSW files", "*.ipsw")])).grid(row=1, column=2)

ctk.CTkLabel(create_ipsw_frame, text="Keys File:").grid(row=2, column=0, sticky="e")
ctk.CTkEntry(create_ipsw_frame, textvariable=keys_var, width=300).grid(row=2, column=1, padx=5, pady=5)
ctk.CTkButton(create_ipsw_frame, text="Browse...", command=lambda: browse_file(keys_var, [("ZIP files", "*.zip")])).grid(row=2, column=2)

ctk.CTkLabel(create_ipsw_frame, text="Output File:").grid(row=3, column=0, sticky="e")
ctk.CTkEntry(create_ipsw_frame, textvariable=output_var, width=300).grid(row=3, column=1, padx=5, pady=5)
ctk.CTkButton(create_ipsw_frame, text="Browse...", command=lambda: browse_file(output_var, [("IPSW files", "*.ipsw")])).grid(row=3, column=2)

ctk.CTkButton(create_ipsw_frame, text="RUN", command=run_script).grid(row=4, column=0, columnspan=3, pady=10)

# Flash IPSW section
flash_ipsw_frame = ctk.CTkFrame(root)
flash_ipsw_frame.grid(row=2, column=0, columnspan=3, padx=10, pady=10, sticky="ew")
flash_ipsw_frame.grid_columnconfigure(1, weight=1)

ctk.CTkLabel(flash_ipsw_frame, text="IPSW File:").grid(row=0, column=0, sticky="e")
ctk.CTkEntry(flash_ipsw_frame, textvariable=flash_ipsw_var, width=300).grid(row=0, column=1, padx=5, pady=5)
ctk.CTkButton(flash_ipsw_frame, text="Browse...", command=lambda: browse_file(flash_ipsw_var, [("IPSW files", "*.ipsw")])).grid(row=0, column=2)

ctk.CTkButton(flash_ipsw_frame, text="Flash IPSW", command=flash_ipsw).grid(row=1, column=0, columnspan=3, pady=10)

# Key Generation section (commented out)
# keygen_frame = ctk.CTkFrame(root)
# keygen_frame.grid(row=3, column=0, columnspan=3, padx=10, pady=10, sticky="ew")
# keygen_frame.grid_columnconfigure(1, weight=1)

# ctk.CTkLabel(keygen_frame, text="Key Output File:").grid(row=0, column=0, sticky="e")
# ctk.CTkEntry(keygen_frame, textvariable=keygen_output_var, width=300).grid(row=0, column=1, padx=5, pady=5)
# ctk.CTkButton(keygen_frame, text="Browse...", command=lambda: browse_file(keygen_output_var, [("ZIP files", "*.zip")])).grid(row=0, column=2)

# ctk.CTkButton(keygen_frame, text="Generate Keys", command=start_generate_keys).grid(row=1, column=0, columnspan=3, pady=10)

# Add the STOP ALL PROCESSES button
stop_button = ctk.CTkButton(root, text="STOP ALL PROCESSES", command=stop_all_processes)
stop_button.grid(row=4, column=2, padx=10, pady=10, sticky="e")

# Output Log
output_text = ctk.CTkTextbox(root, height=20, width=80)
output_text.grid(row=4, column=0, columnspan=3, padx=10, pady=10, sticky="nsew")

# Start the main loop
root.mainloop()
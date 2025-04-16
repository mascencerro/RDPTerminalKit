#!/usr/bin/env python3

from tkinter import *
import tkinter.messagebox
import customtkinter as ctk
import configparser
import socket
import subprocess
import platform

configfile = "/etc/rdpconfig.ini"
config = configparser.ConfigParser(allow_no_value=True)

try:
    config.read('/etc/rdpconfig.ini')
except:
    print(f"Error reading configuration file {configfile}")
    exit(1)

# Cosmetics
WINDOW_TITLE = LOGIN_HEADER = config.get('Appearance', 'LoginHeader', fallback="Remote Desktop Login")
WINDOW_WIDTH = int(config.get('Window', 'Width', fallback=800))
WINDOW_HEIGHT = int(config.get('Window', 'Height', fallback=420))
WIDGET_SCALING = int(config.get('Window', 'Scaling', fallback=2))

HEADER_BG_COLOR = config.get('Appearance', 'LoginHeaderBGColor', fallback="#708090")
HEADER_TEXT_COLOR = config.get('Appearance', 'LoginHeaderTextColor', fallback="black")

LOGIN_BG_COLOR = config.get('Appearance', 'LoginBGColor', fallback="silver")
LOGIN_TEXT_COLOR = config.get('Appearance', 'LoginTextColor', fallback="black")

BORDER_COLOR = config.get('Appearance', 'BorderColor', fallback='black')

_HEADER_FONT = config.get('Appearance', 'HeaderFont', fallback='Arial,20,bold').split(',')
_LABEL_FONT = config.get('Appearance', 'LabelFont', fallback='Verdana,16,bold').split(',')
_ENTRY_FONT = config.get('Appearance', 'EntryFont', fallback='Verdana,16,normal').split(',')
_BUTTON_FONT = config.get('Appearance', 'ButtonFont', fallback='Arial,14,bold').split(',')
_INFO_FONT = config.get('Appearance', 'InfoFont', fallback='Courier,8,normal').split(',')

ctk.set_default_color_theme("blue") 
ctk.set_appearance_mode("system") 
ctk.set_widget_scaling(WIDGET_SCALING)

# Define connection information
if config.has_option('Connection', 'TerminalHost'):
    terminal_hostname = config.get('Connection', 'TerminalHost')
else:
    terminal_hostname = socket.gethostname()

if config.has_option('Connection', 'RemoteHost'):
    terminal_vmhost = config.get('Connection', 'RemoteHost')
else:
    terminal_vmhost = f"{terminal_hostname}V"

if config.has_option('Connection', 'RemotePort'):
    terminal_vmhost_port = int(config.get('Connection', 'RemotePort'))
else:
    terminal_vmhost_port = 3389         # Default RDP port

if config.has_option('Connection', 'Domain'):
    domain = config.get('Connection', 'Domain')
else:
    domain = socket.getfqdn().split('.', 1)[1]

# Guardrail for testing script and layout on Windows system (dont need to connect)
# If system is Windows use stub client_connect()
if (any(platform.win32_ver())):
    system_is_windows = True
    
    # stub function we wont need for testing layout
    def client_connect(username=None, password=None):
        pass
    
else:
    system_is_windows = False

    # Check that VM hostname is resolvable and get IP address
    # FreeRDP has a tendency sometimes to fail resolving hostnames so we take care of that here
    vmhost_resolve = False
    while not vmhost_resolve:
        try:
            vmhost_fqdn = f"{terminal_vmhost}.{domain}"
            terminal_vmhost_ip = socket.gethostbyname(vmhost_fqdn)
            vmhost_resolve = True
        except Exception as e:
            vmhost_resolve = False
            tkinter.messagebox.showerror(title="Host Resolution Error", message=f"Could not resolve host: {vmhost_fqdn}.\n\nPlease check network connection and try again.\n\n{e}")


    # Connection function - runs xfreerdp as subprocess to connect to VM
    def client_connect(username = None, password = None):
        # Set up FreeRDP runtime options
        client_connect_args = ['xfreerdp']

        if config.has_option('Options', 'Fullscreen'):
            client_connect_args.append('/f')                                        # fullscreen
        if config.has_option('Options', 'MultiDisplay'):
            client_connect_args.append('/multimon')                                 # multiple display support
        if config.has_option('Options', 'SoundOut'):
            client_connect_args.append('/sound:sys:pulse,channel:2,rate:44100')     # Audio out support
        if config.has_option('Options', 'SoundIn'):
            client_connect_args.append('/microphone')                               # Audio in support
        if config.has_option('Options', 'USBHotplug'):
            client_connect_args.append('/usb:auto')                                 # USB device support
        if config.has_option('Options', 'USBDrives'):
            client_connect_args.append('/drive:hotplug,*')                          # USB mass storage hotplug support
        if not config.has_option('Options', 'CertificateCheck'):        
            client_connect_args.append('/cert:ignore')                              # Ignore certificate
        if config.has_option('Options', 'DebugUSB'):
            client_connect_args.append('/log-filters:com.freerdp.channels.urbdrc.client:DEBUG')
        if config.has_option('Options', 'DebugSound'):
            client_connect_args.append('/log-filters:com.freerdp.channels.rdpsnd.client:DEBUG')

        client_connect_args.append(f'/v:{terminal_vmhost_ip}')                  # Terminal hostname to connect to
        client_connect_args.append(f'/u:{username}')
        client_connect_args.append(f'/p:{password}')
        client_connect_args.append(f'/port:{terminal_vmhost_port}')
        
        # Is this a local system or domain login?
        if not ('.\\' in username[0:2]):
            client_connect_args.append(f'/d:{domain}')
        
        # Infinite loop so dialog doesn't reset unless user presses 'cancel' on connection failure
        while True:
            try:
                # Test for connection to vmhost
                s = socket.socket()
                s.connect((terminal_vmhost_ip, terminal_vmhost_port))
                s.close()
                
                # Let's goooooo
                subprocess.run(client_connect_args)
                exit()
                
            except Exception as e:
                print(f"Encountered error: {e}")
                # If user presses CANCEL we break loop and subsequently exit (leaving session between X and God to handle)
                if not (tkinter.messagebox.askretrycancel(message=f"Could not connect to remote host.\n\nPlease check network connection.\n\n{e}")):
                    break
        
        exit()


# Lets create an interface to see what we're doing.
def login_window():
    
    def process_login(event=None):
        username = username_entry.get()
        password = password_entry.get()
        
        if not ((username == '') or (password == '')):
            client_connect(username=username, password=password)
            exit()
        else:
            tkinter.messagebox.showinfo("Missing Information", "Username and password need to be entered to log-in.")

    
    def cancel_login(event=None):
        exit()
    
    app = ctk.CTk()
    app.geometry(f"{WINDOW_WIDTH}x{WINDOW_HEIGHT}")
    app.title(WINDOW_TITLE)

    HEADER_FONT = ctk.CTkFont(family=_HEADER_FONT[0], size=int(_HEADER_FONT[1]), weight=_HEADER_FONT[2])
    LABEL_FONT = ctk.CTkFont(family=_LABEL_FONT[0], size=int(_LABEL_FONT[1]), weight=_LABEL_FONT[2])
    ENTRY_FONT = ctk.CTkFont(family=_ENTRY_FONT[0], size=int(_ENTRY_FONT[1]), weight=_ENTRY_FONT[2])
    BUTTON_FONT = ctk.CTkFont(family=_BUTTON_FONT[0], size=int(_BUTTON_FONT[1]), weight=_BUTTON_FONT[2])
    INFO_FONT = ctk.CTkFont(family=_INFO_FONT[0], size=int(_INFO_FONT[1]), weight=_INFO_FONT[2])

    # Main window frame
    window_frame = ctk.CTkFrame(master=app, border_width=1, bg_color=BORDER_COLOR, width=(WINDOW_WIDTH / WIDGET_SCALING), height=(WINDOW_HEIGHT / WIDGET_SCALING))
    window_frame.pack()

    # Login window header
    header_frame = ctk.CTkFrame(master=window_frame, border_width=1, border_color=BORDER_COLOR, height=35, fg_color=HEADER_BG_COLOR)
    header_frame.place(in_=window_frame, x=5, y=5, relwidth=0.97)

    header_label = ctk.CTkLabel(master=header_frame, font=HEADER_FONT, text=LOGIN_HEADER, text_color=HEADER_TEXT_COLOR, bg_color=HEADER_BG_COLOR)
    header_label.place(anchor='center', relx=0.5, rely=0.5)

    window_frame.update()

    # Login frame
    login_frame = ctk.CTkFrame(master=window_frame, border_width=1, border_color=BORDER_COLOR, height=150, fg_color=LOGIN_BG_COLOR)
    login_frame.place(in_=window_frame, x=5, y=45, relwidth=0.97)

    # Username
    username_label = ctk.CTkLabel(master=login_frame, font=LABEL_FONT, text='Username:', text_color=LOGIN_TEXT_COLOR)
    username_label.place(in_=login_frame, anchor='center', relx=0.25, rely=0.2)

    username_entry = ctk.CTkEntry(master=login_frame, font=ENTRY_FONT, text_color=LOGIN_TEXT_COLOR, width=205)
    username_entry.place(in_=login_frame, anchor='w', relx=0.4, rely=0.2)

    # Password
    password_label = ctk.CTkLabel(master=login_frame, font=LABEL_FONT, text='Password:', text_color=LOGIN_TEXT_COLOR)
    password_label.place(in_=login_frame, anchor='center', relx=0.25, rely=0.5)

    password_entry = ctk.CTkEntry(master=login_frame, show='*', font=ENTRY_FONT, text_color=LOGIN_TEXT_COLOR, width=205)
    password_entry.place(in_=login_frame, anchor='w', relx=0.4, rely=0.5)

    # Buttons
    cancel_button = ctk.CTkButton(master=login_frame, text='Cancel', font=BUTTON_FONT, command=cancel_login)
    cancel_button.place(relx=0.25, rely=0.8, anchor='center')

    login_button = ctk.CTkButton(master=login_frame, text='Login', font=BUTTON_FONT, command=process_login)
    login_button.place(relx=0.75, rely=0.8, anchor='center')

    machine_label = ctk.CTkLabel(master=window_frame, font=INFO_FONT, text=terminal_hostname, text_color=LOGIN_TEXT_COLOR, height=10)
    machine_label.place(in_=window_frame, anchor='se', relx=0.98, rely=0.99)

    # Set Username entry box as first focus
    username_entry.focus()

    # Bind 'Enter' key to process_login
    app.bind('<Return>', process_login)

    app.mainloop()


def main():
    login_window()

if __name__ == '__main__':
    main()

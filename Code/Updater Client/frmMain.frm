VERSION 5.00
Begin VB.Form frmMain 
   BackColor       =   &H80000005&
   BorderStyle     =   1  'Fixed Single
   Caption         =   "Update Client"
   ClientHeight    =   1965
   ClientLeft      =   45
   ClientTop       =   330
   ClientWidth     =   3045
   Icon            =   "frmMain.frx":0000
   LinkTopic       =   "Form1"
   MaxButton       =   0   'False
   MinButton       =   0   'False
   ScaleHeight     =   131
   ScaleMode       =   3  'Pixel
   ScaleWidth      =   203
   StartUpPosition =   2  'CenterScreen
   Begin VB.Timer CloseTimer 
      Enabled         =   0   'False
      Interval        =   200
      Left            =   2520
      Top             =   120
   End
   Begin VB.Label ConnectCmd 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Connect"
      BeginProperty Font 
         Name            =   "MS Sans Serif"
         Size            =   12
         Charset         =   0
         Weight          =   700
         Underline       =   0   'False
         Italic          =   0   'False
         Strikethrough   =   0   'False
      EndProperty
      ForeColor       =   &H80000008&
      Height          =   300
      Left            =   960
      TabIndex        =   9
      Top             =   1560
      Width           =   1020
   End
   Begin VB.Label StatusLbl 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Connecting..."
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   840
      TabIndex        =   8
      Top             =   1200
      Width           =   945
   End
   Begin VB.Label Label3 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Status :"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   240
      TabIndex        =   7
      Top             =   1200
      Width           =   540
   End
   Begin VB.Label FileLbl 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "..."
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   240
      TabIndex        =   6
      Top             =   480
      Width           =   135
   End
   Begin VB.Label Label2 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Current File :"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   240
      TabIndex        =   5
      Top             =   240
      Width           =   885
   End
   Begin VB.Label Label7 
      BackStyle       =   0  'Transparent
      Caption         =   "KB/Sec"
      ForeColor       =   &H80000008&
      Height          =   255
      Left            =   1560
      TabIndex        =   4
      Top             =   960
      Width           =   735
   End
   Begin VB.Label spid 
      Alignment       =   1  'Right Justify
      BackStyle       =   0  'Transparent
      Caption         =   "0"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   840
      TabIndex        =   3
      Top             =   960
      Width           =   570
   End
   Begin VB.Label Label5 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Speed :"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   240
      TabIndex        =   2
      Top             =   960
      Width           =   555
   End
   Begin VB.Label PercentLbl 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "0%"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   1320
      TabIndex        =   1
      Top             =   720
      Width           =   210
   End
   Begin VB.Label Label1 
      AutoSize        =   -1  'True
      BackStyle       =   0  'Transparent
      Caption         =   "Downloaded :"
      ForeColor       =   &H80000008&
      Height          =   195
      Left            =   240
      TabIndex        =   0
      Top             =   720
      Width           =   990
   End
End
Attribute VB_Name = "frmMain"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = False
Attribute VB_PredeclaredId = True
Attribute VB_Exposed = False
Option Explicit

'The update works in the following manner:
' - Server creates overall update list and MD5 hashes for each list, list & hashes is compressed and stored in memory
' - Client connects to the server and downloads the list off the server
' - Client decompresses the list, checks which files it needs to update
' - For every file the client needs to update, it sends a request to the server
' - After each download, the MD5 hash is compared with the one from the server to varify file contents

Private Sub Connect()

    'Set the status
    ConnectCmd.Enabled = False
    StatusLbl.Caption = "Connecting..."

    'Set up the socket
    LocalID = GOREsock_Connect("127.0.0.1", 10201)
    
     'Check for invalid LocalID (did not connect)
    If LocalID = -1 Then
        StatusLbl.Caption = "Unable to connect!"
        ConnectCmd.Enabled = True
    Else
        GOREsock_SetOption LocalID, soxSO_TCP_NODELAY, False
    End If
    
End Sub

Private Sub CloseTimer_Timer()

    'Quit the updater - we must user a timer since DoEvents wont work (since we're not multithreaded)
    Unload Me
    End

End Sub

Private Sub ConnectCmd_Click()

    Connect

End Sub

Private Sub Form_Load()
    
    'Check for the decompress programs
    If LenB(Dir$(App.Path & "\Data\7za.exe")) = 0 Or LenB(Dir$(App.Path & "\Data\mac.exe")) = 0 Then
        MsgBox "You must include the following files to run this program:" & vbNewLine & _
            " * \Data\7za.exe" & vbNewLine & " * \Data\mac.exe", vbOKOnly
        End
    End If
    
    GOREsock_Initialize Me.hWnd
    InitFilePaths
    Me.Show
    DoEvents

End Sub

Private Sub Form_MouseDown(Button As Integer, Shift As Integer, X As Single, Y As Single)

    ReleaseCapture
    SendMessage Me.hWnd, &HA1, 2, 0&

    'Close form
    If Button = vbLeftButton Then
        If X >= Me.ScaleWidth - 23 Then
            If X <= Me.ScaleWidth - 10 Then
                If Y <= 26 Then
                    If Y >= 11 Then
                        Unload Me
                    End If
                End If
            End If
        End If
    End If

End Sub

Private Sub Form_Unload(Cancel As Integer)
Static Cancels As Byte

    If GOREsock_ShutDown = soxERROR Then
        Cancels = Cancels + 1
        If Cancels < 3 Then
            Let Cancel = True
        Else
            GOREsock_UnHook  'Force unload
        End If
    Else
        GOREsock_UnHook
    End If

End Sub

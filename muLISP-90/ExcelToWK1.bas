Attribute VB_Name = "ExcelToWK1"
' ==========================================================
'
' Routines for exporting the content of an Excel Worksheet to a
' file in Lotus 1-2-3 for MS-DOS WK1 format.
'
' Developed and tested in VBA in Excel 2010
'
' Martin Hepperle, 2025
'
' ==========================================================

' This type encapsulates a WK1 file record.
Type Record
 rType As Integer
 rLength As Integer
 rData(511) As Byte
End Type

' These two types are used for converting an IEEE Double to Bytes.
Type IEEEbyte
    d(7) As Byte
End Type

Type IEEEdouble
    d As Double
End Type
' ==========================================================
'
' Test program
'
' Martin Hepperle, 2025
'
' ----------------------------------------------------------
Sub testExportWK1()
    Dim fileName  As String
    Dim formulasToText As Boolean
    
    ' too long for MS-DOS
    fileName = Application.ActiveWorkbook.ActiveSheet.Name + "_" + Application.ActiveWorkbook.Name
    
    fileName = "D:/DOS/123/EXCEL.WK1"
    formulasToText = False
    
    Call exportWK1(fileName, formulasToText)

End Sub
' ==========================================================
'
' Export the used range of an Excel spreadsheet
' to a file in Lotus 1-2-3 WK1 format.
'
' fileName      - name of the file to write in WK1 format.
' formulasToText - whether formulas should be exported as
'                  text or as their numeric result.
'
' - Integer numbers will be exported as INTEGER cells
' - Double numbers will be exported as NUMBER cells
' - Text and Formulas will be exported as ASCIIZ cells
'
' Martin Hepperle, 2025
'
' ----------------------------------------------------------
Sub exportWK1(fileName As String, formulasToText As Boolean)

Dim theRecord As Record

Dim row As Integer
Dim col As Integer
Dim s As String
Dim unit As Integer

' record types
Const rType_BOF As Integer = 0
Const rType_EOF As Integer = 1
Const rType_INTEGER As Integer = 13
Const rType_NUMBER As Integer = 14
Const rType_TEXT As Integer = 15

Dim theSheet As Worksheet
Set theSheet = Application.ActiveWorkbook.ActiveSheet

If Len(Dir(fileName)) > 0 Then
    FileCopy fileName, fileName + ".BAK"
    Kill fileName
    MsgBox "Existing File has been renamed '" + fileName + ".BAK'."
End If

unit = 1
Open fileName For Binary As #unit

' BOF
theRecord.rType = rType_BOF
theRecord.rLength = 2
theRecord.rData(0) = 6
theRecord.rData(1) = 4

Call putRecord(unit, theRecord)

For row = 1 To theSheet.UsedRange.Rows.count
    For col = 1 To theSheet.UsedRange.Columns.count
        Dim n As Integer
        Dim d As Double
        Dim theCell As Range

        Set theCell = theSheet.Cells(row, col)
        s = theCell.Text
        
        If Len(Trim$(s)) > 0 Then
            ' cell is not empty    
            
            If formulasToText And theCell.HasFormula Then
                ' For now, we simply translate the whole sheband
                ' to a text string for manual editing
                s = theCell.Formula
                
                ' TODO: convert formula
                ' - use a table with translation pairs "SIN" -> "@SIN"
                ' - translate references
                ' - translate formula into RPL byte code
                ' - flag non-translatable functions
            End If
            
            If IsNumeric(s) Then
                ' try to convert integer and double numbers
                d = CDbl(s)
                n = CInt(s)

                If n = d Then
                    ' 16-bit Integer
                    theRecord.rType = rType_INTEGER
                    theRecord.rLength = 5 + 2
                    theRecord.rData(0) = 255 ' format
                    Call copyWord(theRecord.rData(), 1, col - 1)
                    Call copyWord(theRecord.rData(), 3, row - 1)
                    Call copyWord(theRecord.rData(), 5, n)
                Else
                    ' 64-bit IEEE Number
                    theRecord.rType = rType_NUMBER
                    theRecord.rLength = 5 + 8
                    theRecord.rData(0) = 255 ' format
                    Call copyWord(theRecord.rData(), 1, col - 1)
                    Call copyWord(theRecord.rData(), 3, row - 1)
                    Call copyDouble(theRecord.rData(), 5, d)
                End If
            Else
                ' ASCIIZ
                s = "'" + s
                theRecord.rType = rType_TEXT
                theRecord.rLength = 5 + Len(s) + 1
                theRecord.rData(0) = 255 ' format
                Call copyWord(theRecord.rData(), 1, col - 1)
                Call copyWord(theRecord.rData(), 3, row - 1)
                Call copyStringZ(theRecord.rData(), 5, s)
            End If
            
            Call putRecord(unit, theRecord)

        End If
    Next col
Next row


' EOF
theRecord.rType = rType_EOF
theRecord.rLength = 2
theRecord.rData(0) = 0
theRecord.rData(1) = 0

Call putRecord(unit, theRecord)

Close #unit

End Sub
' ==========================================================
' Output one Lotus 1-2-3 WK1 file record to the file
' opened as unit.
' ----------------------------------------------------------
Sub putRecord(unit As Integer, r As Record)

    Call putWord(unit, r.rType)
    Call putWord(unit, r.rLength)
    Call putBytes(unit, r.rData(), r.rLength)

End Sub
' ==========================================================
' Output one 16-bit word w to the file opened as unit.
' The word is written in Intel low-high-byte order.
' ----------------------------------------------------------
Sub putWord(unit As Integer, w As Integer)

    Put #unit, , Chr$(w And &HFF) ' low byte
    Put #unit, , Chr$((w \ 256) And &HFF) ' high byte

End Sub
' ==========================================================
' Output count 16-bit words from the array w()
' to the file opened as unit.
' The words are written in Intel low-high-byte order.
' ----------------------------------------------------------
Sub putWords(unit As Integer, w() As Integer, count As Integer)
    Dim i As Integer
    
    For i = 0 To count - 1
        Put #unit, , Chr$(w(i) And &HFF) ' low byte
        Put #unit, , Chr$((w(i) \ 256) And &HFF) ' high byte
    Next i

End Sub
' ==========================================================
' Output count Bytes from the array w()
' to the file opened as unit.
' ----------------------------------------------------------
Sub putBytes(unit As Integer, b() As Byte, count As Integer)
    Dim i As Integer
    
    For i = 0 To count - 1
        Put #unit, , Chr$(b(i))
    Next i

End Sub

' ==========================================================
' Copy a 16 bit integer word into the byte array b(),
' starting at index idx.
' The word is stored in Intel low-high-byte order.
' ----------------------------------------------------------
Sub copyWord(b() As Byte, idx As Integer, w As Integer)

    b(idx) = (w And &HFF) ' low byte
    b(idx + 1) = (w \ 256) And &HFF ' high byte

End Sub
' ==========================================================

' ==========================================================
' Copy a string into the byte array b(), starting at index idx.
' The string is terminated with an appended 0-byte.
' ----------------------------------------------------------
Sub copyStringZ(b() As Byte, idx As Integer, s As String)
    Dim i As Integer
    
    For i = 1 To Len(s)
        b(idx) = Asc(Mid$(s, i, 1))
        idx = idx + 1
    Next i
    b(idx) = 0
End Sub
' ==========================================================
' Copy a Double into the byte array b(), starting at index idx.
' Apply some Basic trickery to convert the 8-byte IEEE 754 number
' into bytes.
' The word is stored in Intel low-to-high-byte order.
' ----------------------------------------------------------
Sub copyDouble(b() As Byte, idx As Integer, d As Double)
    Dim i As Integer
    Dim db As IEEEbyte
    Dim dd As IEEEdouble
    
    dd.d = d ' set the double value
    LSet db = dd ' copy its bytes
    
    ' finally copy the bytes to the record
    For i = 0 To 7
        b(idx) = db.d(i)
        idx = idx + 1
    Next i
End Sub
' *EOF*

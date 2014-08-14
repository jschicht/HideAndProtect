#RequireAdmin
#Region ;**** Directives created by AutoIt3Wrapper_GUI ****
#AutoIt3Wrapper_UseUpx=n
#AutoIt3Wrapper_Change2CUI=y
#AutoIt3Wrapper_Res_Comment=Hide and protect files on NTFS
#AutoIt3Wrapper_Res_Description=Hide and protect files on NTFS
#AutoIt3Wrapper_Res_Fileversion=1.0.0.2
#AutoIt3Wrapper_Res_requestedExecutionLevel=asInvoker
#AutoIt3Wrapper_Res_File_Add=C:\tmp\sectorio.sys
#AutoIt3Wrapper_Res_File_Add=C:\tmp\sectorio64.sys
#EndRegion ;**** Directives created by AutoIt3Wrapper_GUI ****
#Include <WinAPIEx.au3>
#include <Array.au3>
#Include <String.au3>
#include <Constants.au3>
;
; https://github.com/jschicht
; http://code.google.com/p/mft2csv/
;
Global Const $IOCTL_DISK_GET_PARTITION_INFO_EX = 0x00070048
Global Const $FSCTL_DISMOUNT_VOLUME = 0x00090020
Global Const $FSCTL_LOCK_VOLUME = 0x00090018
Global Const $FSCTL_UNLOCK_VOLUME = 0x0009001C
Global $nBytes, $TargetDrive,$TargetFile,$NewIndexNumber, $DefaultIndexNumber = 12, $IsDirectory, $NeedUnLock=0, $ManualInteractionNeeded=0, $DoWipeOnly=0, $TargetFileNameStr=""
Global $TargetImageFile, $Entries, $InputFile, $IsShadowCopy=False, $IsPhysicalDrive=False, $IsImage=False, $hDisk, $sBuffer, $ComboPhysicalDrives, $Combo
Global $OutPutPath=@ScriptDir, $InitState = False, $DATA_Clusters, $AttributeOutFileName, $DATA_InitSize, $ImageOffset, $ADS_Name, $bIndexNumber, $NonResidentFlag, $DATA_RealSize, $DataRun, $DATA_LengthOfAttribute
Global $TargetDrive = "", $ALInnerCouner, $MFTSize, $TargetOffset, $SectorsPerCluster,$MFT_Record_Size,$BytesPerCluster,$BytesPerSector,$MFT_Offset,$IsDirectory
Global $IsolatedAttributeList, $AttribListNonResident=0,$IsCompressed,$IsSparse,$Drivername = "sectorio", $DoDriver=0
Global $RUN_VCN[1],$RUN_Clusters[1],$MFT_RUN_Clusters[1],$MFT_RUN_VCN[1],$DataQ[1],$AttribX[1],$AttribXType[1],$AttribXCounter[1],$sBuffer,$AttrQ[1]
Global Const $RecordSignature = '46494C45' ; FILE signature
Global Const $RecordSignatureBad = '44414142' ; BAAD signature
Global Const $STANDARD_INFORMATION = '10000000'
Global Const $ATTRIBUTE_LIST = '20000000'
Global Const $FILE_NAME = '30000000'
Global Const $OBJECT_ID = '40000000'
Global Const $SECURITY_DESCRIPTOR = '50000000'
Global Const $VOLUME_NAME = '60000000'
Global Const $VOLUME_INFORMATION = '70000000'
Global Const $DATA = '80000000'
Global Const $INDEX_ROOT = '90000000'
Global Const $INDEX_ALLOCATION = 'A0000000'
Global Const $BITMAP = 'B0000000'
Global Const $REPARSE_POINT = 'C0000000'
Global Const $EA_INFORMATION = 'D0000000'
Global Const $EA = 'E0000000'
Global Const $PROPERTY_SET = 'F0000000'
Global Const $LOGGED_UTILITY_STREAM = '00010000'
Global Const $ATTRIBUTE_END_MARKER = 'FFFFFFFF'
Global Const $FileInternalInformation = 6
Global Const $OBJ_CASE_INSENSITIVE = 0x00000040
Global Const $FILE_DIRECTORY_FILE = 0x00000002
Global Const $FILE_NON_DIRECTORY_FILE = 0x00000040
Global Const $FILE_RANDOM_ACCESS = 0x00000800
Global Const $tagIOSTATUSBLOCK = "dword Status;ptr Information"
Global Const $tagOBJECTATTRIBUTES = "ulong Length;hwnd RootDirectory;ptr ObjectName;ulong Attributes;ptr SecurityDescriptor;ptr SecurityQualityOfService"
Global Const $tagUNICODESTRING = "ushort Length;ushort MaximumLength;ptr Buffer"
Global Const $tagFILEINTERNALINFORMATION = "int IndexNumber;"

ConsoleWrite("HideAndProtect v1.0.0.2" & @crlf & @crlf)
_ValidateInput()
_ReadBootSector($TargetDrive)
$BytesPerCluster = $SectorsPerCluster*$BytesPerSector
$MFTEntry = _FindMFT(0)
_DecodeMFTRecord($MFTEntry,0)
_DecodeDataQEntry($DataQ[1])
$MFTSize = $DATA_RealSize
Global $RUN_VCN[1], $RUN_Clusters[1]
_ExtractDataRuns()
$MFT_RUN_VCN = $RUN_VCN
$MFT_RUN_Clusters = $RUN_Clusters
;-------------------------------------- New file
$NewFile = _FindFileMFTRecord($NewIndexNumber)
$OffsetNewFile = $NewFile[0]
$RecordNewFile = $NewFile[1]
;------------------------------------- Original file
If Not $DoWipeOnly Then
	$OriginalFile = _FindFileMFTRecord($TargetFile)
	$OffsetOriginalFile = $OriginalFile[0]
	$RecordOriginalFile = $OriginalFile[1]
	_DecodeMFTRecord($RecordOriginalFile,1)

; Reassemble new record. No fixups applied.
	If $MFT_Record_Size = 1024 Then
		$part1 = StringMid($RecordOriginalFile,1,34)
		$SeqNum = _SwapEndian(Hex($NewIndexNumber,4))
		$part2 = StringMid($RecordOriginalFile,39,8)
		If $IsDirectory Then
			$HeaderFlag = "0300"
		Else
			$HeaderFlag = "0100"
		EndIf
		$part3 = StringMid($RecordOriginalFile,51,40)
		$MftRef = _SwapEndian(Hex($NewIndexNumber,8))
		$part4 = StringMid($RecordOriginalFile,99,1952)
		$NewReassembledRecord = $part1&$SeqNum&$part2&$HeaderFlag&$part3&$MftRef&$part4
	ElseIf $MFT_Record_Size = 4096 Then
		$part1 = StringMid($RecordOriginalFile,1,34)
		$SeqNum = _SwapEndian(Hex($NewIndexNumber,4))
		$part2 = StringMid($RecordOriginalFile,39,8)
		If $IsDirectory Then
			$HeaderFlag = "0300"
		Else
			$HeaderFlag = "0100"
		EndIf
		$part3 = StringMid($RecordOriginalFile,51,40)
		$MftRef = _SwapEndian(Hex($NewIndexNumber,8))
		$part4 = StringMid($RecordOriginalFile,99,8096)
		$NewReassembledRecord = $part1&$SeqNum&$part2&$HeaderFlag&$part3&$MftRef&$part4
	EndIf

; Set deleted flag in old record
	If $MFT_Record_Size = 1024 Then
		$partA = StringMid($RecordOriginalFile,1,46)
		If $IsDirectory Then
			$HeaderFlagA = "0200"
		Else
			$HeaderFlagA = "0000"
		EndIf
		$partB = StringMid($RecordOriginalFile,51,2000)
		$OldReassembledRecord = $partA&$HeaderFlagA&$partB
	ElseIf $MFT_Record_Size = 4096 Then
		$partA = StringMid($RecordOriginalFile,1,46)
		If $IsDirectory Then
			$HeaderFlagA = "0200"
		Else
			$HeaderFlagA = "0000"
		EndIf
		$partB = StringMid($RecordOriginalFile,51,8144)
		$OldReassembledRecord = $partA&$HeaderFlagA&$partB
	EndIf

	$tBuffer2 = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	$tBuffer3 = DllStructCreate("byte[" & $MFT_Record_Size & "]")

	DllStructSetData($tBuffer2,1,$OldReassembledRecord)
	DllStructSetData($tBuffer3,1,$NewReassembledRecord)

	$DiskHandle = _GetDiskHandle($TargetDrive)
	;-----------------------------------------
	If $DiskHandle=0 Then
		$DiskHandle = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
		If $DiskHandle=0 Then
			ConsoleWrite("Error: Accessing volume: " & $TargetDrive & @CRLF)
			Exit
		EndIf
		$DoDriver=1
		;Determine correct registry location
		If @AutoItX64 Then
			;ConsoleWrite("64-bit mode" & @CRLF)
			$RegRoot = "HKLM64"
		Else
			;ConsoleWrite("32-bit mode" & @CRLF)
			$RegRoot = "HKLM"
		EndIf

		If @OSArch = "X86" Then
			$DriverFile = @ScriptDir&"\sectorio.sys"
			$TargetRCDataNumber = 1
		Else
			$DriverFile = @ScriptDir&"\sectorio64.sys"
			$TargetRCDataNumber = 2
		EndIf

		Local $ServiceName = $Drivername
		If Not _PrepareDriver() Then
			ConsoleWrite("Error: Loading driver" & @CRLF)
			Exit
		EndIf
	EndIf
	;--------------------------------------------

	If Not $DoDriver Then
		;Original record
		_WinAPI_SetFilePointerEx($DiskHandle, $OffsetOriginalFile)
		_WinAPI_WriteFile($DiskHandle, DllStructGetPtr($tBuffer2), $MFT_Record_Size, $nBytes)
		If _WinAPI_GetLastError() <> 0 Then
			ConsoleWrite("Error: WriteFile original record returned: " & _WinAPI_GetLastErrorMessage() & @crlf)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes for original record at volume offset: 0x" & Hex($OffsetOriginalFile) & @crlf)
		EndIf
		_WinAPI_FlushFileBuffers($DiskHandle)
		;New record
		_WinAPI_SetFilePointerEx($DiskHandle, $OffsetNewFile)
		_WinAPI_WriteFile($DiskHandle, DllStructGetPtr($tBuffer3), $MFT_Record_Size, $nBytes)
		If _WinAPI_GetLastError() <> 0 Then
			ConsoleWrite("Error: WriteFile new record returned: " & _WinAPI_GetLastErrorMessage() & @crlf)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes for new record at volume offset: 0x" & Hex($OffsetNewFile) & @crlf)
		EndIf
		If @OSBuild >= 6000 And $NeedUnLock Then
			_WinAPI_UnLockVolume($DiskHandle)
			If @error Then ConsoleWrite("Error: UnLockVolume returned " & _WinAPI_GetLastErrorMessage() & @CRLF)
		EndIf
	Else
		ConsoleWrite("Trying to write with driver.." & @crlf)
		;Original record
		$DriverJobOk = _SectorIo($TargetDrive,$OffsetOriginalFile,$tBuffer2)
		If @error or $DriverJobOk = 0 Then
			ConsoleWrite("Error: Driver could not write data to disk" & @crlf)
			_NtUnloadDriver($ServiceName)
			FileDelete($DriverFile)
			RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes for original record at volume offset: 0x" & Hex($OffsetOriginalFile) & @crlf)
		EndIf
		;New record
		$DriverJobOk = _SectorIo($TargetDrive,$OffsetNewFile,$tBuffer3)
		If @error or $DriverJobOk = 0 Then
			ConsoleWrite("Error: Driver could not write data to disk" & @crlf)
			_NtUnloadDriver($ServiceName)
			FileDelete($DriverFile)
			RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes for new record at volume offset: 0x" & Hex($OffsetNewFile) & @crlf)
		EndIf
	EndIf
	_WinAPI_CloseHandle($DiskHandle)
	ConsoleWrite(@crlf)
	ConsoleWrite("ATTENTION: You must now manually run this command:" & @CRLF)
	ConsoleWrite("chkdsk " & $TargetDrive & " /F" & @CRLF)
	;Exit
Else
; This will just set the deleted flag in record header. Fixups not applied
	If $MFT_Record_Size = 1024 Then
		$partA = StringMid($RecordNewFile,1,46)
		If $IsDirectory Then
			$HeaderFlagA = "0200"
		Else
			$HeaderFlagA = "0000"
		EndIf
		$partB = StringMid($RecordNewFile,51,2000)
		$OldReassembledRecord = $partA&$HeaderFlagA&$partB
	ElseIf $MFT_Record_Size = 4096 Then
		$partA = StringMid($RecordNewFile,1,46)
		If $IsDirectory Then
			$HeaderFlagA = "0200"
		Else
			$HeaderFlagA = "0000"
		EndIf
		$partB = StringMid($RecordNewFile,51,8144)
		$OldReassembledRecord = $partA&$HeaderFlagA&$partB
	EndIf

	$DiskHandle = _GetDiskHandle($TargetDrive)
	;--------------------------------------------
	If $DiskHandle=0 Then
		$DiskHandle = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
		If $DiskHandle=0 Then
			ConsoleWrite("Error: Accessing volume: " & $TargetDrive & @CRLF)
			Exit
		EndIf
		$DoDriver=1
		;Determine correct registry location
		If @AutoItX64 Then
			;ConsoleWrite("64-bit mode" & @CRLF)
			$RegRoot = "HKLM64"
		Else
			;ConsoleWrite("32-bit mode" & @CRLF)
			$RegRoot = "HKLM"
		EndIf

		If @OSArch = "X86" Then
			$DriverFile = @ScriptDir&"\sectorio.sys"
			$TargetRCDataNumber = 1
		Else
			$DriverFile = @ScriptDir&"\sectorio64.sys"
			$TargetRCDataNumber = 2
		EndIf

		Local $ServiceName = $Drivername
		If Not _PrepareDriver() Then
			ConsoleWrite("Error: Loading driver" & @CRLF)
			Exit
		EndIf
	EndIf
	;-----------------------------------------------------------------------
	$tBuffer2 = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	DllStructSetData($tBuffer2,1,$OldReassembledRecord)
;------------------------------------------------------------------------------
	If Not $DoDriver Then
		_WinAPI_SetFilePointerEx($DiskHandle, $OffsetNewFile)
		_WinAPI_WriteFile($DiskHandle, DllStructGetPtr($tBuffer2), $MFT_Record_Size, $nBytes)
		If _WinAPI_GetLastError() <> 0 Then
			ConsoleWrite("Error: WriteFile original record returned: " & _WinAPI_GetLastErrorMessage() & @crlf)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes at volume offset: 0x" & Hex($OffsetNewFile) & @crlf)
		EndIf
		_WinAPI_FlushFileBuffers($DiskHandle)
		If @OSBuild >= 6000 And $NeedUnLock Then
			_WinAPI_UnLockVolume($DiskHandle)
			If @error Then ConsoleWrite("Error: UnLockVolume returned " & _WinAPI_GetLastErrorMessage() & @CRLF)
		EndIf
	Else
		ConsoleWrite("Trying to write with driver.." & @crlf)
		$DriverJobOk = _SectorIo($TargetDrive,$OffsetNewFile,$tBuffer2)
		If @error or $DriverJobOk = 0 Then
			ConsoleWrite("Error: Driver could not write data to disk" & @crlf)
			_NtUnloadDriver($ServiceName)
			FileDelete($DriverFile)
			RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
			Exit
		Else
			ConsoleWrite("Success writing " & $MFT_Record_Size & " bytes at volume offset: 0x" & Hex($OffsetNewFile) & @crlf)
		EndIf
	EndIf
	_WinAPI_CloseHandle($DiskHandle)
	ConsoleWrite(@crlf)
	ConsoleWrite("ATTENTION: You must now manually run this command:" & @CRLF)
	ConsoleWrite("chkdsk " & $TargetDrive & " /F" & @CRLF)
	;Exit
EndIf
If $DoDriver Then
	_NtUnloadDriver($ServiceName)
	FileDelete($DriverFile)
	RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
EndIf
Exit

Func _GetDiskHandle($TargetDrive)
	If @OSBuild >= 6000 Then
		If StringLeft(@AutoItExe,2) = $TargetDrive Then
			ConsoleWrite("Error: you can't lock the volume that this program is run from without driver" & @crlf)
			Return 0
		EndIf
		If StringLeft(@SystemDir,2) = $TargetDrive Then
			ConsoleWrite("Error: Locking the system volume is not possible on nt6.x without driver" & @crlf)
			Return 0
		EndIf
		$hDiskMod = _WinAPI_LockVolume($TargetDrive)
		If @error Then
			ConsoleWrite("Error when locking " & $TargetDrive & @CRLF)
			ConsoleWrite("Trying to force dismount instead " & @CRLF)
			$hDiskMod = _WinAPI_DismountVolumeMod($TargetDrive)
			If $hDiskMod = 0 Then
				ConsoleWrite("Error when force dismounting " & $TargetDrive & @CRLF)
				Return 0
			EndIf
			$ManualInteractionNeeded = 1
			ConsoleWrite("Force dismounted " & $TargetDrive & @CRLF)
		Else
			$NeedUnLock = 1
			ConsoleWrite("Locked " & $TargetDrive & @CRLF)
		EndIf
	ElseIf @OSBuild < 6000 Then
		Local $hDiskMod = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,6,7)
		If $hDiskMod = 0 then
			ConsoleWrite("Error: CreateFile returned " & _WinAPI_GetLastErrorMessage() & @CRLF)
			Return 0
		EndIf
	EndIf
	Return $hDiskMod
EndFunc

Func _ValidateInput()
	If $cmdline[0] <> 2 Then
		ConsoleWrite("Usage:" & @CRLF)
		ConsoleWrite("HideAndProtect param1 DestinationIndexNumber" & @CRLF)
		ConsoleWrite("	param1 can be:" & @CRLF)
		ConsoleWrite("		1. path to source file to be hidden" & @CRLF)
		ConsoleWrite("		2. Volume and IndexNumber of the source file to be hidden" & @CRLF)
		ConsoleWrite("		3. Volume and W switch indicating a wipe of the DestinationIndexNumber " & @CRLF)
		ConsoleWrite("	DestinationIndexNumber is the new MFT reference/Index/inode number (between 12 - 15)" & @CRLF & @CRLF)
		ConsoleWrite("Example using path to source file and target IndexNumber 12:" & @CRLF)
		ConsoleWrite("HideAndProtect C:\bootmgr 12" & @CRLF & @CRLF)
		ConsoleWrite("Example using IndexNumber of source file (33) on volume C: and target IndexNumber 13:" & @CRLF)
		ConsoleWrite("HideAndProtect C:33 13" & @CRLF & @CRLF)
		ConsoleWrite("Example to wipe the record of MFT reference number 14 on volume C:" & @CRLF)
		ConsoleWrite("HideAndProtect C:W 14" & @CRLF)
		Exit
	EndIf
	If FileExists($cmdline[1]) <> 1 Then
		If StringInStr($cmdline[1],":W") Then
			$TargetDrive = StringMid($cmdline[1],1,2)
			$TargetFile = ""
			$DoWipeOnly = 1
		ElseIf StringMid($cmdline[1],2,1) = ":" Then
			If StringIsDigit(StringMid($cmdline[1],3)) <> 1 Then
				ConsoleWrite("Error: File not found in Param1: " & $cmdline[1] & @CRLF)
				Exit
			EndIf
			$TargetFile = StringMid($cmdline[1],3)
			$TargetDrive = StringMid($cmdline[1],1,2)
		Else
			ConsoleWrite("Error: File probably locked" & @CRLF)
			Exit
		EndIf
	Else
		$FileAttrib = FileGetAttrib($cmdline[1])
		If @error Or $FileAttrib="" Then
			ConsoleWrite("Error: Could not retrieve file attributes" & @CRLF)
			Exit
		EndIf
		If $FileAttrib <> "D" Then
			$IsDirectory = 0
			ConsoleWrite("Target is a File" & @CRLF)
		EndIf
		If $FileAttrib = "D" Then
			$IsDirectory = 1
			ConsoleWrite("Target is a Directory" & @CRLF)
		EndIf
		$TargetFile = _GetIndexNumber($cmdline[1], $IsDirectory)
		If Not StringIsDigit($TargetFile) Or @error Then
			ConsoleWrite($TargetFile & @CRLF)
			Exit
		EndIf
		$TargetDrive = StringMid($cmdline[1],1,2)
		$TargetFileNameStr = $cmdline[1]
	EndIf
;----------------------------------
	If StringIsDigit($cmdline[2]) <> 1 Then
		ConsoleWrite("Error: param2 not a valid IndexNumber" & @CRLF)
	Else
		If $cmdline[2] < 12 Or $cmdline[2] > 15 Then
			ConsoleWrite("Error new IndexNumber set outside of the range of reserved and available NTFS system files" & @CRLF)
			Exit
		EndIf
		$NewIndexNumber = $cmdline[2]
	EndIf
	if DriveGetFileSystem($TargetDrive) <> "NTFS" then
		ConsoleWrite("Error: Target volume " & $TargetDrive & " is not NTFS" & @crlf)
		Exit
	EndIf
EndFunc

Func _GetIndexNumber($file, $mode)
	Local $IndexNumber
    Local $hNTDLL = DllOpen("ntdll.dll")
    Local $szName = DllStructCreate("wchar[260]")
    Local $sUS = DllStructCreate($tagUNICODESTRING)
    Local $sOA = DllStructCreate($tagOBJECTATTRIBUTES)
    Local $sISB = DllStructCreate($tagIOSTATUSBLOCK)
    Local $buffer = DllStructCreate("byte[16384]")
    Local $ret, $FILE_MODE
    If $mode == 0 Then
        $FILE_MODE = $FILE_NON_DIRECTORY_FILE
    Else
        $FILE_MODE = $FILE_DIRECTORY_FILE
    EndIf
    $file = "\??\" & $file
    DllStructSetData($szName, 1, $file)
    $ret = DllCall($hNTDLL, "none", "RtlInitUnicodeString", "ptr", DllStructGetPtr($sUS), "ptr", DllStructGetPtr($szName))
    DllStructSetData($sOA, "Length", DllStructGetSize($sOA))
    DllStructSetData($sOA, "RootDirectory", 0)
    DllStructSetData($sOA, "ObjectName", DllStructGetPtr($sUS))
    DllStructSetData($sOA, "Attributes", $OBJ_CASE_INSENSITIVE)
    DllStructSetData($sOA, "SecurityDescriptor", 0)
    DllStructSetData($sOA, "SecurityQualityOfService", 0)
    $ret = DllCall($hNTDLL, "int", "NtOpenFile", "hwnd*", "", "dword", $GENERIC_READ, "ptr", DllStructGetPtr($sOA), "ptr", DllStructGetPtr($sISB), _
                                "ulong", $FILE_SHARE_READ, "ulong", BitOR($FILE_MODE, $FILE_RANDOM_ACCESS))
	If NT_SUCCESS($ret[0]) Then
;		ConsoleWrite("NtOpenFile: Success" & @CRLF)
	Else
		ConsoleWrite("Error: NtOpenFile returned: 0x" & Hex($ret[0],8) & @CRLF)
		Return SetError(1,0,"Error: NtOpenFile returned: 0x" & Hex($ret[0],8))
	EndIf
    Local $hFile = $ret[1]
    $ret = DllCall($hNTDLL, "int", "NtQueryInformationFile", "hwnd", $hFile, "ptr", DllStructGetPtr($sISB), "ptr", DllStructGetPtr($buffer), _
                                "int", 16384, "ptr", $FileInternalInformation)

    If NT_SUCCESS($ret[0]) Then
        Local $pFSO = DllStructGetPtr($buffer)
		Local $sFSO = DllStructCreate($tagFILEINTERNALINFORMATION, $pFSO)
		Local $IndexNumber = DllStructGetData($sFSO, "IndexNumber")
    Else
        ConsoleWrite("Error: NtQueryInformationFile returned: 0x" & Hex($ret[0],8) & @CRLF)
		Return SetError(1,0,"Error: NtQueryInformationFile returned: 0x" & Hex($ret[0],8))
    EndIf
    $ret = DllCall($hNTDLL, "int", "NtClose", "hwnd", $hFile)
    DllClose($hNTDLL)
	Return $IndexNumber
EndFunc

Func _ExtractSystemfile($TargetFile)
	Global $DataQ[1], $RUN_VCN[1], $RUN_Clusters[1],$AttribX[1], $AttribXType[1], $AttribXCounter[1]
	If StringLen($TargetDrive)=1 Then $TargetDrive=$TargetDrive&":"
	_ReadBootSector($TargetDrive)
	$BytesPerCluster = $SectorsPerCluster*$BytesPerSector
	$MFTEntry = _FindMFT(0)
	_DecodeMFTRecord($MFTEntry,0)
	_DecodeDataQEntry($DataQ[1])
	$MFTSize = $DATA_RealSize
	Global $RUN_VCN[1], $RUN_Clusters[1]
	_ExtractDataRuns()
	$MFT_RUN_VCN = $RUN_VCN
	$MFT_RUN_Clusters = $RUN_Clusters
	_ExtractSingleFile(Int($TargetFile,2))
	_WinAPI_CloseHandle($hDisk)
EndFunc

Func _ExtractSingleFile($MFTReferenceNumber)
	Global $DataQ[1],$AttribX[1],$AttribXType[1],$AttribXCounter[1]				;clear array
	$MFTRecord = _FindFileMFTRecord($MFTReferenceNumber)
	If $MFTRecord[1] = "" Then
		ConsoleWrite("Target " & $MFTReferenceNumber & " not found" & @CRLF)
		Return SetError(1,0,0)
	ElseIf StringMid($MFTRecord[1],3,8) <> $RecordSignature AND StringMid($MFTRecord[1],3,8) <> $RecordSignatureBad Then
		ConsoleWrite("Found record is not valid:" & @CRLF)
		ConsoleWrite(_HexEncode($MFTRecord[1]) & @crlf)
		Return SetError(1,0,0)
	EndIf
	_DecodeMFTRecord($MFTRecord[1],1)
	Return
EndFunc

Func _DecodeAttrList($TargetFile, $AttrList)
	Local $offset, $length, $nBytes, $hFile, $LocalAttribID, $LocalName, $ALRecordLength, $ALNameLength, $ALNameOffset
	If StringMid($AttrList, 17, 2) = "00" Then		;attribute list is in $AttrList
		$offset = Dec(_SwapEndian(StringMid($AttrList, 41, 4)))
		$List = StringMid($AttrList, $offset*2+1)
;		$IsolatedAttributeList = $list
	Else			;attribute list is found from data run in $AttrList
		$size = Dec(_SwapEndian(StringMid($AttrList, $offset*2 + 97, 16)))
		$offset = ($offset + Dec(_SwapEndian(StringMid($AttrList, $offset*2 + 65, 4))))*2
		$DataRun = StringMid($AttrList, $offset+1, StringLen($AttrList)-$offset)
;		ConsoleWrite("Attribute_List DataRun is " & $DataRun & @CRLF)
		Global $RUN_VCN[1], $RUN_Clusters[1]
		_ExtractDataRuns()
		$tBuffer = DllStructCreate("byte[" & $BytesPerCluster & "]")
		$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 6, 6)
		If $hFile = 0 Then
			ConsoleWrite("Error in function CreateFile when trying to locate Attribute List." & @CRLF)
			_WinAPI_CloseHandle($hFile)
			Return SetError(1,0,0)
		EndIf
		$List = ""
		For $r = 1 To Ubound($RUN_VCN)-1
			_WinAPI_SetFilePointerEx($hFile, $RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
			For $i = 1 To $RUN_Clusters[$r]
				_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $BytesPerCluster, $nBytes)
				$List &= StringTrimLeft(DllStructGetData($tBuffer, 1),2)
			Next
		Next
;		_DebugOut("***AttrList New:",$List)
		_WinAPI_CloseHandle($hFile)
		$List = StringMid($List, 1, $size*2)
	EndIf
	$IsolatedAttributeList = $list
	$offset=0
	$str=""
	While StringLen($list) > $offset*2
		$type=StringMid($List, ($offset*2)+1, 8)
		$ALRecordLength = Dec(_SwapEndian(StringMid($List, $offset*2 + 9, 4)))
		$ALNameLength = Dec(_SwapEndian(StringMid($List, $offset*2 + 13, 2)))
		$ALNameOffset = Dec(_SwapEndian(StringMid($List, $offset*2 + 15, 2)))
		$TestVCN = Dec(_SwapEndian(StringMid($List, $offset*2 + 17, 16)))
		$ref=Dec(_SwapEndian(StringMid($List, $offset*2 + 33, 8)))
		$LocalAttribID = "0x" & StringMid($List, $offset*2 + 49, 2) & StringMid($List, $offset*2 + 51, 2)
		If $ALNameLength > 0 Then
			$LocalName = StringMid($List, $offset*2 + 53, $ALNameLength*2*2)
			$LocalName = _UnicodeHexToStr($LocalName)
		Else
			$LocalName = ""
		EndIf
		If $ref <> $TargetFile Then		;new attribute
			If Not StringInStr($str, $ref) Then $str &= $ref & "-"
		EndIf
		If $type=$DATA Then
			$DataInAttrlist=1
			$IsolatedData=StringMid($List, ($offset*2)+1, $ALRecordLength*2)
			If $TestVCN=0 Then $DataIsResident=1
		EndIf
		$offset += Dec(_SwapEndian(StringMid($List, $offset*2 + 9, 4)))
	WEnd
	If $str = "" Then
		ConsoleWrite("No extra MFT records found" & @CRLF)
	Else
		$AttrQ = StringSplit(StringTrimRight($str,1), "-")
;		ConsoleWrite("Decode of $ATTRIBUTE_LIST reveiled extra MFT Records to be examined = " & _ArrayToString($AttrQ, @CRLF) & @CRLF)
	EndIf
EndFunc

Func _StripMftRecord($MFTEntry)
	$UpdSeqArrOffset = Dec(_SwapEndian(StringMid($MFTEntry,11,4)))
	$UpdSeqArrSize = Dec(_SwapEndian(StringMid($MFTEntry,15,4)))
	$UpdSeqArr = StringMid($MFTEntry,3+($UpdSeqArrOffset*2),$UpdSeqArrSize*2*2)

	If $MFT_Record_Size = 1024 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 Then
			_DebugOut("The record failed Fixup", $MFTEntry)
			Return ""
		EndIf
		$MFTEntry = StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2
	ElseIf $MFT_Record_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		Local $RecordEnd3 = StringMid($MFTEntry,3071,4)
		Local $RecordEnd4 = StringMid($MFTEntry,4095,4)
		Local $RecordEnd5 = StringMid($MFTEntry,5119,4)
		Local $RecordEnd6 = StringMid($MFTEntry,6143,4)
		Local $RecordEnd7 = StringMid($MFTEntry,7167,4)
		Local $RecordEnd8 = StringMid($MFTEntry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			_DebugOut("The record failed Fixup", $MFTEntry)
			Return ""
		Else
			$MFTEntry =  StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2 & StringMid($MFTEntry,2051,1020) & $UpdSeqArrPart3 & StringMid($MFTEntry,3075,1020) & $UpdSeqArrPart4 & StringMid($MFTEntry,4099,1020) & $UpdSeqArrPart5 & StringMid($MFTEntry,5123,1020) & $UpdSeqArrPart6 & StringMid($MFTEntry,6147,1020) & $UpdSeqArrPart7 & StringMid($MFTEntry,7171,1020) & $UpdSeqArrPart8
		EndIf
	EndIf

	$RecordSize = Dec(_SwapEndian(StringMid($MFTEntry,51,8)),2)
	$HeaderSize = Dec(_SwapEndian(StringMid($MFTEntry,43,4)),2)
	$MFTEntry = StringMid($MFTEntry,$HeaderSize*2+3,($RecordSize-$HeaderSize-8)*2)        ;strip "0x..." and "FFFFFFFF..."
	Return $MFTEntry
EndFunc

Func _DecodeDataQEntry($attr)		;processes data attribute
   $NonResidentFlag = StringMid($attr,17,2)
   $NameLength = Dec(StringMid($attr,19,2))
   $NameOffset = Dec(_SwapEndian(StringMid($attr,21,4)))
   If $NameLength > 0 Then		;must be ADS
	  $ADS_Name = _UnicodeHexToStr(StringMid($attr,$NameOffset*2 + 1,$NameLength*4))
   Else
	  $ADS_Name = ""
   EndIf
   $Flags = StringMid($attr,25,4)
   If BitAND($Flags,"0100") Then $IsCompressed = 1
   If BitAND($Flags,"0080") Then $IsSparse = 1
   If $NonResidentFlag = '01' Then
	  $DATA_Clusters = Dec(_SwapEndian(StringMid($attr,49,16)),2) - Dec(_SwapEndian(StringMid($attr,33,16)),2) + 1
	  $DATA_RealSize = Dec(_SwapEndian(StringMid($attr,97,16)),2)
	  $DATA_InitSize = Dec(_SwapEndian(StringMid($attr,113,16)),2)
	  $Offset = Dec(_SwapEndian(StringMid($attr,65,4)))
	  $DataRun = StringMid($attr,$Offset*2+1,(StringLen($attr)-$Offset)*2)
   ElseIf $NonResidentFlag = '00' Then
	  $DATA_LengthOfAttribute = Dec(_SwapEndian(StringMid($attr,33,8)),2)
	  $Offset = Dec(_SwapEndian(StringMid($attr,41,4)))
	  $DataRun = StringMid($attr,$Offset*2+1,$DATA_LengthOfAttribute*2)
   EndIf
EndFunc

Func _DecodeMFTRecord($MFTEntry,$MFTMode)
Local $MFTEntryOrig,$FN_Number,$DATA_Number,$SI_Number,$ATTRIBLIST_Number,$OBJID_Number,$SECURITY_Number,$VOLNAME_Number,$VOLINFO_Number,$INDEXROOT_Number,$INDEXALLOC_Number,$BITMAP_Number,$REPARSEPOINT_Number,$EAINFO_Number,$EA_Number,$PROPERTYSET_Number,$LOGGEDUTILSTREAM_Number
Local $RecordHdrArr[16][2]
$HEADER_RecordRealSize = ""
$HEADER_MFTREcordNumber = ""
$UpdSeqArrOffset = Dec(_SwapEndian(StringMid($MFTEntry,11,4)))
$UpdSeqArrSize = Dec(_SwapEndian(StringMid($MFTEntry,15,4)))
$UpdSeqArr = StringMid($MFTEntry,3+($UpdSeqArrOffset*2),$UpdSeqArrSize*2*2)

	If $MFT_Record_Size = 1024 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 Then
			;_DebugOut("The record failed Fixup", $MFTEntry)
			ConsoleWrite("Error: the $MFT record is corrupt" & @CRLF)
			Return SetError(1,0,0)
		EndIf
		$MFTEntry = StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2
	ElseIf $MFT_Record_Size = 4096 Then
		Local $UpdSeqArrPart0 = StringMid($UpdSeqArr,1,4)
		Local $UpdSeqArrPart1 = StringMid($UpdSeqArr,5,4)
		Local $UpdSeqArrPart2 = StringMid($UpdSeqArr,9,4)
		Local $UpdSeqArrPart3 = StringMid($UpdSeqArr,13,4)
		Local $UpdSeqArrPart4 = StringMid($UpdSeqArr,17,4)
		Local $UpdSeqArrPart5 = StringMid($UpdSeqArr,21,4)
		Local $UpdSeqArrPart6 = StringMid($UpdSeqArr,25,4)
		Local $UpdSeqArrPart7 = StringMid($UpdSeqArr,29,4)
		Local $UpdSeqArrPart8 = StringMid($UpdSeqArr,33,4)
		Local $RecordEnd1 = StringMid($MFTEntry,1023,4)
		Local $RecordEnd2 = StringMid($MFTEntry,2047,4)
		Local $RecordEnd3 = StringMid($MFTEntry,3071,4)
		Local $RecordEnd4 = StringMid($MFTEntry,4095,4)
		Local $RecordEnd5 = StringMid($MFTEntry,5119,4)
		Local $RecordEnd6 = StringMid($MFTEntry,6143,4)
		Local $RecordEnd7 = StringMid($MFTEntry,7167,4)
		Local $RecordEnd8 = StringMid($MFTEntry,8191,4)
		If $UpdSeqArrPart0 <> $RecordEnd1 OR $UpdSeqArrPart0 <> $RecordEnd2 OR $UpdSeqArrPart0 <> $RecordEnd3 OR $UpdSeqArrPart0 <> $RecordEnd4 OR $UpdSeqArrPart0 <> $RecordEnd5 OR $UpdSeqArrPart0 <> $RecordEnd6 OR $UpdSeqArrPart0 <> $RecordEnd7 OR $UpdSeqArrPart0 <> $RecordEnd8 Then
			;_DebugOut("The record failed Fixup", $MFTEntry)
			ConsoleWrite("Error: the $MFT record is corrupt" & @CRLF)
			Return SetError(1,0,0)
		Else
			$MFTEntry =  StringMid($MFTEntry,1,1022) & $UpdSeqArrPart1 & StringMid($MFTEntry,1027,1020) & $UpdSeqArrPart2 & StringMid($MFTEntry,2051,1020) & $UpdSeqArrPart3 & StringMid($MFTEntry,3075,1020) & $UpdSeqArrPart4 & StringMid($MFTEntry,4099,1020) & $UpdSeqArrPart5 & StringMid($MFTEntry,5123,1020) & $UpdSeqArrPart6 & StringMid($MFTEntry,6147,1020) & $UpdSeqArrPart7 & StringMid($MFTEntry,7171,1020) & $UpdSeqArrPart8
		EndIf
	EndIf


$HEADER_RecordRealSize = Dec(_SwapEndian(StringMid($MFTEntry,51,8)),2)
If $UpdSeqArrOffset = 48 Then
	$HEADER_MFTREcordNumber = Dec(_SwapEndian(StringMid($MFTEntry,91,8)),2)
Else
	$HEADER_MFTREcordNumber = "NT style"
EndIf
$HEADER_Flags = StringMid($MFTEntry,47,4)
Select
	Case $HEADER_Flags = '0000'
;		$HEADER_Flags = 'FILE'
;		$RecordActive = 'DELETED'
		$IsDirectory=0
	Case $HEADER_Flags = '0100'
;		$HEADER_Flags = 'FILE'
;		$RecordActive = 'ALLOCATED'
		$IsDirectory=0
	Case $HEADER_Flags = '0200'
;		$HEADER_Flags = 'FOLDER'
;		$RecordActive = 'DELETED'
		$IsDirectory=1
	Case $HEADER_Flags = '0300'
;		$HEADER_Flags = 'FOLDER'
;		$RecordActive = 'ALLOCATED'
		$IsDirectory=1
	Case Else
		If $MFTMode=1 Then
			ConsoleWrite("Error: Target not file or folder" & @CRLF)
			Exit
		EndIf
EndSelect
$AttributeOffset = (Dec(StringMid($MFTEntry,43,2))*2)+3

While 1
	$AttributeType = StringMid($MFTEntry,$AttributeOffset,8)
	$AttributeSize = StringMid($MFTEntry,$AttributeOffset+8,8)
	$AttributeSize = Dec(_SwapEndian($AttributeSize),2)
	Select
		Case $AttributeType = $STANDARD_INFORMATION
			$SI_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $SI_Number)
			EndIf
		Case $AttributeType = $ATTRIBUTE_LIST
			If $MFTMode = 1 Then
				ConsoleWrite("Error: This version does not support modification of records which contain $ATTRIBUTE_LIST" & @CRLF)
				Exit
			EndIf
			$ATTRIBLIST_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $ATTRIBLIST_Number)
			EndIf
			$MFTEntryOrig = $MFTEntry
			$AttrList = StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2)
			_DecodeAttrList($HEADER_MFTRecordNumber, $AttrList)		;produces $AttrQ - extra record list
			$str = ""
			For $i = 1 To $AttrQ[0]
				$record = _FindFileMFTRecord($AttrQ[$i])
				$str &= _StripMftRecord($record[1])		;no header or end marker
			Next
			$str &= "FFFFFFFF"		;add end marker
			$MFTEntry = StringMid($MFTEntry,1,($HEADER_RecordRealSize-8)*2+2) & $str       ;strip "FFFFFFFF..." first
   		Case $AttributeType = $FILE_NAME
			$FN_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $FN_Number)
			EndIf
		Case $AttributeType = $OBJECT_ID
			$OBJID_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $OBJID_Number)
			EndIf
		Case $AttributeType = $SECURITY_DESCRIPTOR
			$SECURITY_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $SECURITY_Number)
			EndIf
		Case $AttributeType = $VOLUME_NAME
			$VOLNAME_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $VOLNAME_Number)
			EndIf
		Case $AttributeType = $VOLUME_INFORMATION
			$VOLINFO_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $VOLINFO_Number)
			EndIf
		Case $AttributeType = $DATA
			$DATA_Number += 1
			_ArrayAdd($DataQ, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
		Case $AttributeType = $INDEX_ROOT
			$INDEXROOT_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $INDEXROOT_Number)
			EndIf
		Case $AttributeType = $INDEX_ALLOCATION
			$INDEXALLOC_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $INDEXALLOC_Number)
			EndIf
		Case $AttributeType = $BITMAP
			$BITMAP_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $BITMAP_Number)
			EndIf
		Case $AttributeType = $REPARSE_POINT
			$REPARSEPOINT_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $REPARSEPOINT_Number)
			EndIf
		Case $AttributeType = $EA_INFORMATION
			$EAINFO_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $EAINFO_Number)
			EndIf
		Case $AttributeType = $EA
			$EA_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $EA_Number)
			EndIf
		Case $AttributeType = $PROPERTY_SET
			$PROPERTYSET_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $PROPERTYSET_Number)
			EndIf
		Case $AttributeType = $LOGGED_UTILITY_STREAM
			$LOGGEDUTILSTREAM_Number += 1
			If $MFTMode = 1 Then
				_ArrayAdd($AttribX, StringMid($MFTEntry,$AttributeOffset,$AttributeSize*2))
				_ArrayAdd($AttribXType, $AttributeType)
				_ArrayAdd($AttribXCounter, $LOGGEDUTILSTREAM_Number)
			EndIf
		Case $AttributeType = $ATTRIBUTE_END_MARKER
			ExitLoop
	EndSelect
	$AttributeOffset += $AttributeSize*2
WEnd
;If $MFTMode = 1 Then
;	Return $MFTEntry
;EndIf
EndFunc

Func _ExtractDataRuns()
	$r=UBound($RUN_Clusters)
	$i=1
	$RUN_VCN[0] = 0
	$BaseVCN = $RUN_VCN[0]
	If $DataRun = "" Then $DataRun = "00"
	Do
		$RunListID = StringMid($DataRun,$i,2)
		If $RunListID = "00" Then ExitLoop
		$i += 2
		$RunListClustersLength = Dec(StringMid($RunListID,2,1))
		$RunListVCNLength = Dec(StringMid($RunListID,1,1))
		$RunListClusters = Dec(_SwapEndian(StringMid($DataRun,$i,$RunListClustersLength*2)),2)
		$i += $RunListClustersLength*2
		$RunListVCN = _SwapEndian(StringMid($DataRun, $i, $RunListVCNLength*2))
		;next line handles positive or negative move
		$BaseVCN += Dec($RunListVCN,2)-(($r>1) And (Dec(StringMid($RunListVCN,1,1))>7))*Dec(StringMid("10000000000000000",1,$RunListVCNLength*2+1),2)
		If $RunListVCN <> "" Then
			$RunListVCN = $BaseVCN
		Else
			$RunListVCN = 0			;$RUN_VCN[$r-1]		;0
		EndIf
		If (($RunListVCN=0) And ($RunListClusters>16) And (Mod($RunListClusters,16)>0)) Then
		 ;may be sparse section at end of Compression Signature
			_ArrayAdd($RUN_Clusters,Mod($RunListClusters,16))
			_ArrayAdd($RUN_VCN,$RunListVCN)
			$RunListClusters -= Mod($RunListClusters,16)
			$r += 1
		ElseIf (($RunListClusters>16) And (Mod($RunListClusters,16)>0)) Then
		 ;may be compressed data section at start of Compression Signature
			_ArrayAdd($RUN_Clusters,$RunListClusters-Mod($RunListClusters,16))
			_ArrayAdd($RUN_VCN,$RunListVCN)
			$RunListVCN += $RUN_Clusters[$r]
			$RunListClusters = Mod($RunListClusters,16)
			$r += 1
		EndIf
	  ;just normal or sparse data
		_ArrayAdd($RUN_Clusters,$RunListClusters)
		_ArrayAdd($RUN_VCN,$RunListVCN)
		$r += 1
		$i += $RunListVCNLength*2
	Until $i > StringLen($DataRun)
EndFunc

Func _FindFileMFTRecord($TargetFile)
	Local $nBytes, $TmpOffset, $Counter, $Counter2, $RecordJumper, $TargetFileDec, $RecordsTooMuch, $RetVal[2]
	$tBuffer = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 6, 6)
	If $hFile = 0 Then
		ConsoleWrite("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Return SetError(1,0,0)
	EndIf
	$TargetFile = _DecToLittleEndian($TargetFile)
	$TargetFileDec = Dec(_SwapEndian($TargetFile),2)
	Local $RecordsDivisor = $MFT_Record_Size/512
	For $i = 1 To UBound($MFT_RUN_Clusters)-1
		$CurrentClusters = $MFT_RUN_Clusters[$i]
		$RecordsInCurrentRun = ($CurrentClusters*$SectorsPerCluster)/$RecordsDivisor
		$Counter+=$RecordsInCurrentRun
		If $Counter>$TargetFileDec Then
			ExitLoop
		EndIf
	Next
	$TryAt = $Counter-$RecordsInCurrentRun
	$TryAtArrIndex = $i
	$RecordsPerCluster = $SectorsPerCluster/$RecordsDivisor
	Do
		$RecordJumper+=$RecordsPerCluster
		$Counter2+=1
		$Final = $TryAt+$RecordJumper
	Until $Final>=$TargetFileDec
	$RecordsTooMuch = $Final-$TargetFileDec
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset+$MFT_RUN_VCN[$i]*$BytesPerCluster+($Counter2*$BytesPerCluster)-($RecordsTooMuch*$MFT_Record_Size), $FILE_BEGIN)
	_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $MFT_Record_Size, $nBytes)
	$record = DllStructGetData($tBuffer, 1)
	If StringMid($record,91,8) = $TargetFile Then
		$TmpOffset = DllCall('kernel32.dll', 'int', 'SetFilePointerEx', 'ptr', $hFile, 'int64', 0, 'int64*', 0, 'dword', 1)
		ConsoleWrite("Record number: " & Dec(_SwapEndian($TargetFile),2) & " found at disk offset: " & $TmpOffset[3] & " -> 0x" & Hex($TmpOffset[3]) & @CRLF)
		_WinAPI_CloseHandle($hFile)
		$RetVal[0] = $TmpOffset[3]-$MFT_Record_Size
		$RetVal[1] = $record
		Return $RetVal
	Else
		_WinAPI_CloseHandle($hFile)
		Return ""
	EndIf
EndFunc

Func _FindMFT($TargetFile)
	Local $nBytes;, $MFT_Record_Size=1024
	$tBuffer = DllStructCreate("byte[" & $MFT_Record_Size & "]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive, 2, 2, 7)
	If $hFile = 0 Then
		ConsoleWrite("Error in function CreateFile when trying to locate MFT: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Return SetError(1,0,0)
	EndIf
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset+$MFT_Offset, $FILE_BEGIN)
	_WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), $MFT_Record_Size, $nBytes)
	_WinAPI_CloseHandle($hFile)
	$record = DllStructGetData($tBuffer, 1)
	If NOT StringMid($record,1,8) = '46494C45' Then
		ConsoleWrite("MFT record signature not found. "& @crlf)
		Return ""
	EndIf
	If StringMid($record,47,4) = "0100" AND Dec(_SwapEndian(StringMid($record,91,8))) = $TargetFile Then
;		ConsoleWrite("MFT record found" & @CRLF)
		Return $record		;returns record for MFT
	EndIf
	ConsoleWrite("MFT record not found" & @CRLF)
	Return ""
EndFunc

Func _DecToLittleEndian($DecimalInput)
	Return _SwapEndian(Hex($DecimalInput,8))
EndFunc

Func _SwapEndian($iHex)
	Return StringMid(Binary(Dec($iHex,2)),3, StringLen($iHex))
EndFunc

Func _UnicodeHexToStr($FileName)
	$str = ""
	For $i = 1 To StringLen($FileName) Step 4
		$str &= ChrW(Dec(_SwapEndian(StringMid($FileName, $i, 4))))
	Next
	Return $str
EndFunc

Func _DebugOut($text, $var)
	ConsoleWrite("Debug output for " & $text & @CRLF)
	For $i=1 To StringLen($var) Step 32
		$str=""
		For $n=0 To 15
			$str &= StringMid($var, $i+$n*2, 2) & " "
			if $n=7 then $str &= "- "
		Next
		ConsoleWrite($str & @CRLF)
	Next
EndFunc

Func _ReadBootSector($TargetDrive)
	Local $nbytes
	$tBuffer=DllStructCreate("byte[512]")
	$hFile = _WinAPI_CreateFile("\\.\" & $TargetDrive,2,2,7)
	If $hFile = 0 then
		ConsoleWrite("Error in function CreateFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		Return SetError(1,0,0)
	EndIf
	_WinAPI_SetFilePointerEx($hFile, $ImageOffset, $FILE_BEGIN)
	$read = _WinAPI_ReadFile($hFile, DllStructGetPtr($tBuffer), 512, $nBytes)
	If $read = 0 then
		ConsoleWrite("Error in function ReadFile: " & _WinAPI_GetLastErrorMessage() & " for: " & "\\.\" & $TargetDrive & @crlf)
		Return
	EndIf
	_WinAPI_CloseHandle($hFile)
   ; Good starting point from KaFu & trancexx at the AutoIt forum
	$tBootSectorSections = DllStructCreate("align 1;" & _
								"byte Jump[3];" & _
								"char SystemName[8];" & _
								"ushort BytesPerSector;" & _
								"ubyte SectorsPerCluster;" & _
								"ushort ReservedSectors;" & _
								"ubyte[3];" & _
								"ushort;" & _
								"ubyte MediaDescriptor;" & _
								"ushort;" & _
								"ushort SectorsPerTrack;" & _
								"ushort NumberOfHeads;" & _
								"dword HiddenSectors;" & _
								"dword;" & _
								"dword;" & _
								"int64 TotalSectors;" & _
								"int64 LogicalClusterNumberforthefileMFT;" & _
								"int64 LogicalClusterNumberforthefileMFTMirr;" & _
								"dword ClustersPerFileRecordSegment;" & _
								"dword ClustersPerIndexBlock;" & _
								"int64 NTFSVolumeSerialNumber;" & _
								"dword Checksum", DllStructGetPtr($tBuffer))

	$BytesPerSector = DllStructGetData($tBootSectorSections, "BytesPerSector")
	$SectorsPerCluster = DllStructGetData($tBootSectorSections, "SectorsPerCluster")
	$BytesPerCluster = $BytesPerSector * $SectorsPerCluster
	$ClustersPerFileRecordSegment = DllStructGetData($tBootSectorSections, "ClustersPerFileRecordSegment")
	$LogicalClusterNumberforthefileMFT = DllStructGetData($tBootSectorSections, "LogicalClusterNumberforthefileMFT")
	$MFT_Offset = $BytesPerCluster * $LogicalClusterNumberforthefileMFT
	If $ClustersPerFileRecordSegment > 127 Then
		$MFT_Record_Size = 2 ^ (256 - $ClustersPerFileRecordSegment)
	Else
		$MFT_Record_Size = $BytesPerCluster * $ClustersPerFileRecordSegment
	EndIf
EndFunc

Func _HexEncode($bInput)
    Local $tInput = DllStructCreate("byte[" & BinaryLen($bInput) & "]")
    DllStructSetData($tInput, 1, $bInput)
    Local $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", 0, _
            "dword*", 0)

    If @error Or Not $a_iCall[0] Then
        Return SetError(1, 0, "")
    EndIf

    Local $iSize = $a_iCall[5]
    Local $tOut = DllStructCreate("char[" & $iSize & "]")

    $a_iCall = DllCall("crypt32.dll", "int", "CryptBinaryToString", _
            "ptr", DllStructGetPtr($tInput), _
            "dword", DllStructGetSize($tInput), _
            "dword", 11, _
            "ptr", DllStructGetPtr($tOut), _
            "dword*", $iSize)

    If @error Or Not $a_iCall[0] Then
        Return SetError(2, 0, "")
    EndIf

    Return SetError(0, 0, DllStructGetData($tOut, 1))

EndFunc  ;==>_HexEncode

Func _File_Attributes($FAInput)
	Local $FAOutput = ""
	If BitAND($FAInput, 0x0001) Then $FAOutput &= 'read_only+'
	If BitAND($FAInput, 0x0002) Then $FAOutput &= 'hidden+'
	If BitAND($FAInput, 0x0004) Then $FAOutput &= 'system+'
	If BitAND($FAInput, 0x0010) Then $FAOutput &= 'directory+'
	If BitAND($FAInput, 0x0020) Then $FAOutput &= 'archive+'
	If BitAND($FAInput, 0x0040) Then $FAOutput &= 'device+'
	If BitAND($FAInput, 0x0080) Then $FAOutput &= 'normal+'
	If BitAND($FAInput, 0x0100) Then $FAOutput &= 'temporary+'
	If BitAND($FAInput, 0x0200) Then $FAOutput &= 'sparse_file+'
	If BitAND($FAInput, 0x0400) Then $FAOutput &= 'reparse_point+'
	If BitAND($FAInput, 0x0800) Then $FAOutput &= 'compressed+'
	If BitAND($FAInput, 0x1000) Then $FAOutput &= 'offline+'
	If BitAND($FAInput, 0x2000) Then $FAOutput &= 'not_indexed+'
	If BitAND($FAInput, 0x4000) Then $FAOutput &= 'encrypted+'
	If BitAND($FAInput, 0x8000) Then $FAOutput &= 'integrity_stream+'
	If BitAND($FAInput, 0x10000) Then $FAOutput &= 'virtual+'
	If BitAND($FAInput, 0x20000) Then $FAOutput &= 'no_scrub_data+'
	If BitAND($FAInput, 0x10000000) Then $FAOutput &= 'directory+'
	If BitAND($FAInput, 0x20000000) Then $FAOutput &= 'index_view+'
	$FAOutput = StringTrimRight($FAOutput, 1)
	Return $FAOutput
EndFunc

Func _ExtractFile($record)
	$cBuffer = DllStructCreate("byte[" & $BytesPerCluster * 16 & "]")
    $zflag = 0
	$hFile = _WinAPI_CreateFile($AttributeOutFileName,3,6,7)
	If $hFile Then
		Select
			Case UBound($RUN_VCN) = 1		;no data, do nothing
			Case UBound($RUN_VCN) = 2 	;may be normal or sparse
				If $RUN_VCN[1] = 0 And $IsSparse Then		;sparse
					$FileSize = _DoSparse(1, $hFile, $DATA_InitSize)
				Else								;normal
					$FileSize = _DoNormal(1, $hFile, $cBuffer, $DATA_InitSize)
				EndIf
		    Case Else					;may be compressed
				_DoCompressed($hFile, $cBuffer, $record)
		EndSelect
		If $DATA_RealSize > $DATA_InitSize Then
		    $FileSize = _WriteZeros($hfile, $DATA_RealSize - $DATA_InitSize)
		EndIf
		_WinAPI_CloseHandle($hFile)
		Return
	Else
		ConsoleWrite("Error creating output file: " & _WinAPI_GetLastErrorMessage() & @CRLF)
	EndIf
EndFunc

Func _WriteZeros($hfile, $count)
   Local $nBytes
   If Not IsDllStruct($sBuffer) Then _CreateSparseBuffer()
   While $count > $BytesPerCluster * 16
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * 16, $nBytes)
	  $count -= $BytesPerCluster * 16
	  $ProgressSize = $DATA_RealSize - $count
   WEnd
   If $count <> 0 Then _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $count, $nBytes)
   $ProgressSize = $DATA_RealSize
   Return 0
EndFunc

Func _DoCompressed($hFile, $cBuffer, $record)
   Local $nBytes
   $r=1
   $FileSize = $DATA_InitSize
   $ProgressSize = $FileSize
   Do
	  _WinAPI_SetFilePointerEx($hDisk, $ImageOffset+$RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
	  $i = $RUN_Clusters[$r]
	  If (($RUN_VCN[$r+1]=0) And ($i+$RUN_Clusters[$r+1]=16) And $IsCompressed) Then
		 _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
		 $Decompressed = _LZNTDecompress($cBuffer, $BytesPerCluster * $i)
		 If IsString($Decompressed) Then
			If $r = 1 Then
			   _DebugOut("Decompression error for " & $ADS_Name, $record)
			Else
			   _DebugOut("Decompression error (partial write) for " & $ADS_Name, $record)
			EndIf
			Return
		 Else		;$Decompressed is an array
			Local $dBuffer = DllStructCreate("byte[" & $Decompressed[1] & "]")
			DllStructSetData($dBuffer, 1, $Decompressed[0])
		 EndIf
		 If $FileSize > $Decompressed[1] Then
			_WinAPI_WriteFile($hFile, DllStructGetPtr($dBuffer), $Decompressed[1], $nBytes)
			$FileSize -= $Decompressed[1]
			$ProgressSize = $FileSize
		 Else
			_WinAPI_WriteFile($hFile, DllStructGetPtr($dBuffer), $FileSize, $nBytes)
		 EndIf
		 $r += 1
	  ElseIf $RUN_VCN[$r]=0 Then
		 $FileSize = _DoSparse($r, $hFile, $FileSize)
		 $ProgressSize = 0
	  Else
		 $FileSize = _DoNormal($r, $hFile, $cBuffer, $FileSize)
		 $ProgressSize = 0
	  EndIf
	  $r += 1
   Until $r > UBound($RUN_VCN)-2
   If $r = UBound($RUN_VCN)-1 Then
	  If $RUN_VCN[$r]=0 Then
		 $FileSize = _DoSparse($r, $hFile, $FileSize)
		 $ProgressSize = 0
	  Else
		 $FileSize = _DoNormal($r, $hFile, $cBuffer, $FileSize)
		 $ProgressSize = 0
	  EndIf
   EndIf
EndFunc

Func _DoNormal($r, $hFile, $cBuffer, $FileSize)
   Local $nBytes
   _WinAPI_SetFilePointerEx($hDisk, $ImageOffset+$RUN_VCN[$r]*$BytesPerCluster, $FILE_BEGIN)
   $i = $RUN_Clusters[$r]
   While $i > 16 And $FileSize > $BytesPerCluster * 16
	  _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * 16, $nBytes)
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $BytesPerCluster * 16, $nBytes)
	  $i -= 16
	  $FileSize -= $BytesPerCluster * 16
	  $ProgressSize = $FileSize
   WEnd
   If $i = 0 Or $FileSize = 0 Then Return $FileSize
   If $i > 16 Then $i = 16
   _WinAPI_ReadFile($hDisk, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
   If $FileSize > $BytesPerCluster * $i Then
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $BytesPerCluster * $i, $nBytes)
	  $FileSize -= $BytesPerCluster * $i
	  $ProgressSize = $FileSize
	  Return $FileSize
   Else
	  _WinAPI_WriteFile($hFile, DllStructGetPtr($cBuffer), $FileSize, $nBytes)
	  $ProgressSize = 0
	  Return 0
   EndIf
EndFunc

Func _DoSparse($r,$hFile,$FileSize)
   Local $nBytes
   If Not IsDllStruct($sBuffer) Then _CreateSparseBuffer()
   $i = $RUN_Clusters[$r]
   While $i > 16 And $FileSize > $BytesPerCluster * 16
	 _WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * 16, $nBytes)
	 $i -= 16
	 $FileSize -= $BytesPerCluster * 16
	 $ProgressSize = $FileSize
   WEnd
   If $i <> 0 Then
 	 If $FileSize > $BytesPerCluster * $i Then
		_WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $BytesPerCluster * $i, $nBytes)
		$FileSize -= $BytesPerCluster * $i
		$ProgressSize = $FileSize
	 Else
		_WinAPI_WriteFile($hFile, DllStructGetPtr($sBuffer), $FileSize, $nBytes)
		$ProgressSize = 0
		Return 0
	 EndIf
   EndIf
   Return $FileSize
EndFunc

Func _CreateSparseBuffer()
   Global $sBuffer = DllStructCreate("byte[" & $BytesPerCluster * 16 & "]")
   For $i = 1 To $BytesPerCluster * 16
	  DllStructSetData ($sBuffer, $i, 0)
   Next
EndFunc

Func _LZNTDecompress($tInput, $Size)	;note function returns a null string if error, or an array if no error
	Local $tOutput[2]
	Local $cBuffer = DllStructCreate("byte[" & $BytesPerCluster*16 & "]")
    Local $a_Call = DllCall("ntdll.dll", "int", "RtlDecompressBuffer", _
            "ushort", 2, _
            "ptr", DllStructGetPtr($cBuffer), _
            "dword", DllStructGetSize($cBuffer), _
            "ptr", DllStructGetPtr($tInput), _
            "dword", $Size, _
            "dword*", 0)

    If @error Or $a_Call[0] Then	;if $a_Call[0]=0 then output size is in $a_Call[6], otherwise $a_Call[6] is invalid
        Return SetError(1, 0, "") ; error decompressing
    EndIf
    Local $Decompressed = DllStructCreate("byte[" & $a_Call[6] & "]", DllStructGetPtr($cBuffer))
	$tOutput[0] = DllStructGetData($Decompressed, 1)
	$tOutput[1] = $a_Call[6]
    Return SetError(0, 0, $tOutput)
EndFunc

Func _ExtractResidentFile($Name, $Size, $record)
	Local $nBytes
	$xBuffer = DllStructCreate("byte[" & $Size & "]")
    DllStructSetData($xBuffer, 1, '0x' & $DataRun)
	$hFile = _WinAPI_CreateFile($Name,3,6,7)
	If $hFile Then
		_WinAPI_SetFilePointer($hFile, 0,$FILE_BEGIN)
		_WinAPI_WriteFile($hFile, DllStructGetPtr($xBuffer), $Size, $nBytes)
		_WinAPI_CloseHandle($hFile)
		Return
	Else
		ConsoleWrite("Error" & @CRLF)
	EndIf
EndFunc

Func _TranslateAttributeType($input)
	Local $RetVal
	Select
		Case $input = $STANDARD_INFORMATION
			$RetVal = "$STANDARD_INFORMATION"
		Case $input = $ATTRIBUTE_LIST
			$RetVal = "$ATTRIBUTE_LIST"
		Case $input = $FILE_NAME
			$RetVal = "$FILE_NAME"
		Case $input = $OBJECT_ID
			$RetVal = "$OBJECT_ID"
		Case $input = $SECURITY_DESCRIPTOR
			$RetVal = "$SECURITY_DESCRIPTOR"
		Case $input = $VOLUME_NAME
			$RetVal = "$VOLUME_NAME"
		Case $input = $VOLUME_INFORMATION
			$RetVal = "$VOLUME_INFORMATION"
		Case $input = $DATA
			$RetVal = "$DATA"
		Case $input = $INDEX_ROOT
			$RetVal = "$INDEX_ROOT"
		Case $input = $INDEX_ALLOCATION
			$RetVal = "$INDEX_ALLOCATION"
		Case $input = $BITMAP
			$RetVal = "$BITMAP"
		Case $input = $REPARSE_POINT
			$RetVal = "$REPARSE_POINT"
		Case $input = $EA_INFORMATION
			$RetVal = "$EA_INFORMATION"
		Case $input = $EA
			$RetVal = "$EA"
		Case $input = $PROPERTY_SET
			$RetVal = "$PROPERTY_SET"
		Case $input = $LOGGED_UTILITY_STREAM
			$RetVal = "$LOGGED_UTILITY_STREAM"
		Case $input = $ATTRIBUTE_END_MARKER
			$RetVal = "$ATTRIBUTE_END_MARKER"
	EndSelect
	Return $RetVal
EndFunc

Func NT_SUCCESS($status)
    If 0 <= $status And $status <= 0x7FFFFFFF Then
        Return True
    Else
        Return False
    EndIf
EndFunc

Func _WinAPI_LockVolume($iVolume)
	$hFile = _WinAPI_CreateFileEx('\\.\' & $iVolume, 3, BitOR($GENERIC_READ,$GENERIC_WRITE), 0x7)
	If Not $hFile Then
		Return SetError(1, 0, 0)
	EndIf
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $FSCTL_LOCK_VOLUME, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0, 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		$Ret = 0
	EndIf
	If Not IsArray($Ret) Then
		Return SetError(2, 0, 0)
	EndIf
;	Return $Ret[0]
;	Return $Ret
	Return $hFile
EndFunc   ;==>_WinAPI_LockVolume

Func _WinAPI_UnLockVolume($hFile)
	If Not $hFile Then
		ConsoleWrite("Error in _WinAPI_CreateFileEx when unlocking." & @CRLF)
		Return SetError(1, 0, 0)
	EndIf
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $FSCTL_UNLOCK_VOLUME, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0, 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		$Ret = 0
	EndIf
	If Not IsArray($Ret) Then
		Return SetError(2, 0, 0)
	EndIf
	Return $Ret[0]
EndFunc   ;==>_WinAPI_UnLockVolume

Func _WinAPI_DismountVolume($hFile)
	If Not $hFile Then
		ConsoleWrite("Error in _WinAPI_CreateFileEx when dismounting." & @CRLF)
		Return SetError(1, 0, 0)
	EndIf
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $FSCTL_DISMOUNT_VOLUME, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0, 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		$Ret = 0
	EndIf
	Return $Ret[0]
EndFunc   ;==>_WinAPI_DismountVolume

Func _WinAPI_DismountVolumeMod($iVolume)
	$hFile = _WinAPI_CreateFileEx('\\.\' & $iVolume, 3, BitOR($GENERIC_READ,$GENERIC_WRITE), 0x7)
	If Not $hFile Then
		ConsoleWrite("Error in _WinAPI_CreateFileEx when dismounting." & @CRLF)
		Return SetError(1, 0, 0)
	EndIf
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $FSCTL_DISMOUNT_VOLUME, 'ptr', 0, 'dword', 0, 'ptr', 0, 'dword', 0, 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		Return SetError(3, 0, 0)
	EndIf
	Return $hFile
EndFunc   ;==>_WinAPI_DismountVolumeMod

Func _NtLoadDriver($TargetServiceName)
	$FullServiceName = "\Registry\Machine\SYSTEM\CurrentControlSet\Services\"&$TargetServiceName
	$szName = DllStructCreate("wchar[260]")
	$sUS = DllStructCreate($tagUNICODESTRING)
	DllStructSetData($szName, 1, $FullServiceName)
	$ret = DllCall("ntdll.dll", "none", "RtlInitUnicodeString", "ptr", DllStructGetPtr($sUS), "ptr", DllStructGetPtr($szName))
	$ret = DllCall("ntdll.dll", "int", "NtLoadDriver","ptr",DllStructGetPtr($sUS))
	If Not NT_SUCCESS($ret[0]) And $ret[0] <> 0xC000010E Then
		ConsoleWrite("Error: NtLoadDriver: 0x" & Hex($ret[0])& @CRLF)
		Return SetError(1,0,0)
	EndIf
EndFunc

Func _NtUnloadDriver($TargetServiceName)
	$FullServiceName = "\Registry\Machine\SYSTEM\CurrentControlSet\Services\"&$TargetServiceName
	$szName = DllStructCreate("wchar[260]")
	$sUS = DllStructCreate($tagUNICODESTRING)
	DllStructSetData($szName, 1, $FullServiceName)
	$ret = DllCall("ntdll.dll", "none", "RtlInitUnicodeString", "ptr", DllStructGetPtr($sUS), "ptr", DllStructGetPtr($szName))
	$ret = DllCall("ntdll.dll", "int", "NtUnloadDriver","ptr",DllStructGetPtr($sUS))
	If Not NT_SUCCESS($ret[0]) Then
		ConsoleWrite("Error: NtUnloadDriver: 0x" & Hex($ret[0])& @CRLF)
		Return SetError(1,0,0)
	EndIf
EndFunc

Func _SetPrivilege($Privilege)
    Local $tagLUIDANDATTRIB = "int64 Luid;dword Attributes"
    Local $count = 1
    Local $tagTOKENPRIVILEGES = "dword PrivilegeCount;byte LUIDandATTRIB[" & $count * 12 & "]"
    Local $TOKEN_ADJUST_PRIVILEGES = 0x20
    Local $SE_PRIVILEGE_ENABLED = 0x2

    Local $curProc = DllCall("kernel32.dll", "ptr", "GetCurrentProcess")
	Local $call = DllCall("advapi32.dll", "int", "OpenProcessToken", "ptr", $curProc[0], "dword", $TOKEN_ALL_ACCESS, "ptr*", "")
    If Not $call[0] Then Return False
    Local $hToken = $call[3]

    $call = DllCall("advapi32.dll", "int", "LookupPrivilegeValue", "str", "", "str", $Privilege, "int64*", "")
    Local $iLuid = $call[3]

    Local $TP = DllStructCreate($tagTOKENPRIVILEGES)
	Local $TPout = DllStructCreate($tagTOKENPRIVILEGES)
    Local $LUID = DllStructCreate($tagLUIDANDATTRIB, DllStructGetPtr($TP, "LUIDandATTRIB"))

    DllStructSetData($TP, "PrivilegeCount", $count)
    DllStructSetData($LUID, "Luid", $iLuid)
    DllStructSetData($LUID, "Attributes", $SE_PRIVILEGE_ENABLED)

    $call = DllCall("advapi32.dll", "int", "AdjustTokenPrivileges", "ptr", $hToken, "int", 0, "ptr", DllStructGetPtr($TP), "dword", DllStructGetSize($TPout), "ptr", DllStructGetPtr($TPout), "dword*", 0)
	$lasterror = _WinAPI_GetLastError()
	If $lasterror <> 0 Then
		ConsoleWrite("AdjustTokenPrivileges ("&$Privilege&"): " & _WinAPI_GetLastErrorMessage() & @CRLF)
		DllCall("kernel32.dll", "int", "CloseHandle", "ptr", $hToken)
		Return SetError(1, 0, 0)
	EndIf
    DllCall("kernel32.dll", "int", "CloseHandle", "ptr", $hToken)
    Return ($call[0] <> 0)
EndFunc

Func _DeviceIoControl($hFile, $IoControlCode, $InputBuffer, $OutputBuffer)
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $IoControlCode, 'ptr', DllStructGetPtr($InputBuffer), "ulong", DllStructGetSize($InputBuffer), 'ptr', DllStructGetPtr($OutputBuffer), "ulong", DllStructGetSize($OutputBuffer), 'dword*', 0, 'ptr', 0)
	;ConsoleWrite("DeviceIoControl: 0x" & Hex($Ret[0]) & @CRLF)
	If (@error) Or (Not $Ret[0]) Then
		ConsoleWrite("Error in DeviceIoControl: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		_WinAPI_CloseHandle($hFile)
		Return SetError(1, 0, 0)
	EndIf
	Return $OutputBuffer
EndFunc

Func _SectorIo($TargetVolume,$VolumeOffsetForWrite,$GarbadgeData)
	Local $DiskOffsetForWrite, $PhysicalDriveNoN, $dwDiskObjOrdinal, $ullSectorNumber, $bIsRawDisk = 1, $TargetDevice = "\\.\sectorio", $DriverFile, $TargetRCDataNumber
	Local $tagDISK_LOCATION = "align 1;byte bIsRawDisk;dword dwDiskObjOrdinal;uint64 ullSectorNumber"
	Local $IOCTL_CODE_READ=0x8000E000
	Local $IOCTL_CODE_WRITE=0x8000E004
	Local $IOCTL_CODE_GET_SECTOR_SIZE=0x8000E008
	Local $NewDataSize=DllStructGetSize($GarbadgeData)
	If @error Or $MFT_Record_Size<>$NewDataSize Then
		ConsoleWrite("Error new MFT record buffer invalid" & @CRLF)
		return 0
	EndIf

	;Check offset
	If $VolumeOffsetForWrite = 0 Then
		ConsoleWrite("Error volume offset invalid" & @CRLF)
		return 0
	EndIf

	;Resolve physical offset of volume
	$PartitionInfo = _WinAPI_GetPartitionInfoEx($TargetVolume)
	If @error Then return 0
	$DiskOffsetForWrite = $VolumeOffsetForWrite + $PartitionInfo[1]
	If $DiskOffsetForWrite = 0 Then
		ConsoleWrite("Error disk offset invalid" & @CRLF)
		return 0
	EndIf

	;Determine sector number
	$ullSectorNumber = $DiskOffsetForWrite/$BytesPerSector

	;Work out which PhysicalDrive the volume is on
	If StringLen($TargetVolume)<>2 Then $TargetVolume = StringMid($TargetVolume,1,2)
	$PhysicalDriveN = _WinAPI_GetDriveNumber($TargetVolume)
	If @error Then
		ConsoleWrite("Error in GetDriveNumber: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		Return 0
	EndIf
	$dwDiskObjOrdinal = $PhysicalDriveN[1]
	;ConsoleWrite("Volume resolved to \\.\PhysicalDrive " & $dwDiskObjOrdinal & @CRLF)

	;Prepare buffers
	Local $TestBuffer = DllStructCreate("byte["&$NewDataSize+13&"]")
	If @error Then return 0
	Local $pDISK_LOCATION = DllStructCreate($tagDISK_LOCATION,DllStructGetPtr($TestBuffer))
	If @error Then return 0
	DllStructSetData($pDISK_LOCATION,"bIsRawDisk",$bIsRawDisk)
	If @error Then return 0
	DllStructSetData($pDISK_LOCATION,"dwDiskObjOrdinal",$dwDiskObjOrdinal)
	If @error Then return 0
	DllStructSetData($pDISK_LOCATION,"ullSectorNumber",$ullSectorNumber)
	If @error Then return 0
	Local $pGARBADGE = DllStructCreate("byte["&$NewDataSize&"]",DllStructGetPtr($TestBuffer)+13)
	If @error Then return 0
	;DllStructSetData($pGARBADGE,1,'0x'&$GarbadgeData)
	DllStructSetData($pGARBADGE,1,DllStructGetData($GarbadgeData,1))
	If @error Then return 0
	Local $NewRecordBuff = DllStructCreate("byte["&DllStructGetSize($TestBuffer)&"]",DllStructGetPtr($TestBuffer))
	If @error Then return 0
	;This one is strictly not needed here, and only required with read operations
	Local $OutputBuff2 = DllStructCreate("byte["&$NewDataSize&"]")
	If @error Then return 0

	;Create handle to device
	$hDevice = _WinAPI_CreateFileEx($TargetDevice, $OPEN_EXISTING, BitOR($GENERIC_READ,$GENERIC_WRITE), BitOR($FILE_SHARE_READ,$FILE_SHARE_WRITE),$FILE_ATTRIBUTE_NORMAL)
	If Not $hDevice Then
		ConsoleWrite("Error in CreateFile for " & $TargetDevice & " : " & _WinAPI_GetLastErrorMessage() & @CRLF)
		;_NtUnloadDriver($ServiceName)
		;FileDelete($DriverFile)
		;RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
		return 0
	EndIf

	;Send buffer with data and ioctl to driver
	Local $ResultBuffer2 = _DeviceIoControl($hDevice, $IOCTL_CODE_WRITE, $NewRecordBuff, 0)
	If @error Then
		DllCall("ntdll.dll", "int", "NtClose","handle",$hDevice)
		;_NtUnloadDriver($ServiceName)
		;FileDelete($DriverFile)
		;RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
		return 0
	Else
		DllCall("ntdll.dll", "int", "NtClose","handle",$hDevice)
		;_NtUnloadDriver($ServiceName)
		;FileDelete($DriverFile)
		;RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
		Return $DiskOffsetForWrite
	EndIf
EndFunc

Func _WinAPI_GetPartitionInfoEx($iVolume)
	Local $hFile = _WinAPI_CreateFileEx('\\.\' & $iVolume, 3, 0, 0x03)
	If @error Then
		Return SetError(1, 0, 0)
	EndIf
	Local $pPARTITION_INFORMATION_EX = DllStructCreate("byte;uint64;uint64;dword;byte;byte[116]") ;GPT
	Local $Ret = DllCall('kernel32.dll', 'int', 'DeviceIoControl', 'ptr', $hFile, 'dword', $IOCTL_DISK_GET_PARTITION_INFO_EX, 'ptr', 0, 'dword', 0, 'ptr', DllStructGetPtr($pPARTITION_INFORMATION_EX), 'dword', DllStructGetSize($pPARTITION_INFORMATION_EX), 'dword*', 0, 'ptr', 0)
	If (@error) Or (Not $Ret[0]) Then
		ConsoleWrite("IOCTL_DISK_GET_PARTITION_INFO_EX: " & _WinAPI_GetLastErrorMessage() & @CRLF)
		$Ret = 0
	EndIf
	_WinAPI_CloseHandle($hFile)
	If Not IsArray($Ret) Then
		Return SetError(2, 0, 0)
	EndIf

	Local $Result[6]
	For $i = 0 To 5
		$Result[$i] = DllStructGetData($pPARTITION_INFORMATION_EX, $i + 1)
	Next
	Return $Result
EndFunc

Func _WriteFileFromResource($OutPutName,$RCDataNumber)
	If FileExists($OutPutName) Then FileDelete($OutPutName)
	If Not FileExists($OutPutName) Then
		Local $hResource = _WinAPI_FindResource(0, 10, '#'&$RCDataNumber)
		If @error Or $hResource = 0 Then
			ConsoleWrite("Error: Resource not found" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		Local $iSize = _WinAPI_SizeOfResource(0, $hResource)
		If @error Or $iSize = 0 Then
			ConsoleWrite("Error: Resource size not retrieved" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		Local $hData = _WinAPI_LoadResource(0, $hResource)
		If @error Or $hData = 0 Then
			ConsoleWrite("Error: Resource could not be loaded" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		Local $pData = _WinAPI_LockResource($hData)
		If @error Or $pData = 0 Then
			ConsoleWrite("Error: Resource not locked" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		Local $tBuffer=DllStructCreate('align 1;byte STUB['&$iSize&']', $pData)
		Local $DriverData = DllStructGetData($tBuffer,'STUB')
		If @error or $DriverData = "" Then
			ConsoleWrite("Error: Could not put driver data into buffer" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		Local $hFile = FileOpen($OutPutName,2)
		If Not FileWrite($hFile,$DriverData) Then
			ConsoleWrite("Error: Could not write driver file" & @CRLF)
			Return SetError(1, 0, 0)
		EndIf
		FileClose($hFile)
		Return 1
	Else
		Return 1
	EndIf
EndFunc

Func _PrepareDriver()
	;Determine correct registry location
	If @AutoItX64 Then
		;ConsoleWrite("64-bit mode" & @CRLF)
		$RegRoot = "HKLM64"
	Else
		;ConsoleWrite("32-bit mode" & @CRLF)
		$RegRoot = "HKLM"
	EndIf

	If @OSArch = "X86" Then
		$DriverFile = @ScriptDir&"\sectorio.sys"
		$TargetRCDataNumber = 1
	Else
		$DriverFile = @ScriptDir&"\sectorio64.sys"
		$TargetRCDataNumber = 2
	EndIf

	Local $ServiceName = $Drivername
	Local $ImagePath = "\??\"&$DriverFile

	;Write registry information for service
	RegWrite($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
	RegWrite($RegRoot&"\SYSTEM\CurrentControlSet\Services\"&$ServiceName,"","REG_SZ","")
	RegWrite($RegRoot&"\SYSTEM\CurrentControlSet\Services\"&$ServiceName,"Type","REG_DWORD",1)
	RegWrite($RegRoot&"\SYSTEM\CurrentControlSet\Services\"&$ServiceName,"ImagePath","REG_EXPAND_SZ",$ImagePath)
	RegWrite($RegRoot&"\SYSTEM\CurrentControlSet\Services\"&$ServiceName,"Start","REG_DWORD",3)
	RegWrite($RegRoot&"\SYSTEM\CurrentControlSet\Services\"&$ServiceName,"ErrorControl","REG_DWORD",1)

	;Set permission to load drivers
	_SetPrivilege("SeLoadDriverPrivilege")
	If @error Then
		ConsoleWrite("Error assigning SeLoadDriverPrivilege" & @CRLF)
		return 0
	EndIf

	;Get driver from resource
	_WriteFileFromResource($DriverFile,$TargetRCDataNumber)
	If @error Or FileExists($DriverFile)=0 Then
		ConsoleWrite("Error finding driver" & @CRLF)
		FileDelete($DriverFile)
		return 0
	EndIf

	;Load driver
	_NtLoadDriver($ServiceName)
	If @error Then
		RegDelete($RegRoot & "\SYSTEM\CurrentControlSet\Services\" & $ServiceName)
		FileDelete($DriverFile)
		return 0
	EndIf
	return 1
EndFunc
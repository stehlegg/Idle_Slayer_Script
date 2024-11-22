#include-once
#include <ScreenCapture.au3>
#include <GDIPlus.au3>
#include "UWPOCR.au3"
#include "Common.au3"
#include "ResourcesEx.au3"

Global $mQuestRewardMap = CreateDictionary()

Func CreateDictionary()
    Local $aMap[0]
    Local $sString
    If Not @Compiled Then
        Local $sFile = FileOpen("Resources\QRM.txt")
        $sString = FileRead($sFile)
        FileClose($sFile)
    Else
        $sString = _Resource_GetAsString("QRM")
    EndIf
    WriteInLogs($sString)
    Local $sMap = StringSplit($sString, @LF, 1)
    for $i = 1 To $sMap[0]
        Local $aPart = StringSplit($sMap[$i], "=", 2)
        _ArrayAdd($aMap, $aPart)
    Next
    Return $aMap
EndFunc  ;==>CreateDictionary

Func FindBestMatch($ocrValue)
    Local $aKeys = []
    Local $aValues = []
    Local $sBestKey = ""
    Local $sValue = ""
    Local $iBestKeyIndex
    Local $iLowestDistance = 999999 ; Start with a very high number


    For $i = 0 To UBound($mQuestRewardMap) - 1 Step 2
        _ArrayAdd($aKeys, $mQuestRewardMap[$i])
        _ArrayAdd($aValues, $mQuestRewardMap[$i + 1])
    Next

    For $i = 0 To UBound($aKeys) - 1
        If StringInStr($aKeys[$i], $ocrValue) Then
            $sBestKey = $aKeys[$i]
            $iBestKeyIndex = $i
        Else
            Local $iDistance = LevenshteinDistance(StringLower($aKeys[$i]), StringLower($ocrValue))
            If $iDistance < $iLowestDistance Then
                $iLowestDistance = $iDistance
                $sBestKey = $aKeys[$i]
                $iBestKeyIndex = $i
            EndIf
        EndIf
    Next

    If $sBestKey <> "" Then
        Local $sValue = $aValues[$iBestKeyIndex]
        WriteInLogs("Claimed Quest: " & $sBestKey & " the reward upgrade is: " & $sValue & ", placing on UpgradeWhitelist. Purchasing when all Quests are Processed.")
        Return $sValue
    Else
        WriteInLogs("No matching key found for " & $ocrValue)
        Return SetError(1, 0, "")
    EndIf
EndFunc  ;==>FindeBestMatch

Func ReadQuest($iX1, $iY1, $iX2, $iY2, $bEquip = False, $sWhitelistedUpgrade = "")
    _GDIPlus_Startup()
    Local $hHBitmap = _ScreenCapture_CaptureWnd("", "Idle Slayer", $iX1, $iY1, $iX2, $iY2, False)
    Local $hBitmap = _GDIPlus_BitmapCreateFromHBITMAP($hHBitmap)

    $hBitmap = _GDIPlus_ImageResize($hBitmap, 283, 40)
    Local $sOCRTextResult = StringSplit(_UWPOCR_GetText($hBitmap, Default, True), @LF, 1)[1]

    _WinAPI_DeleteObject($hHBitmap)
    _GDIPlus_BitmapDispose($hBitmap)
    _GDIPlus_Shutdown()

    If $bEquip And $sWhitelistedUpgrade <> "" Then
        WriteInLogs("Desired Upgrade: " & $sWhitelistedUpgrade & ", OCR Upgrade Name: " & $sOCRTextResult)
        If LevenshteinDistance(StringLower($sWhitelistedUpgrade), StringLower($sOCRTextResult)) <= 5 Then
            WriteInLogs("OCR Upgrade Name matches Desired Upgrade name within a margin of Error. Purchasing.")
            WriteInLogs("("&$sWhitelistedUpgrade &" = "& $sOCRTextResult &")")
            Return True
        EndIf
    Else
        Local $sBestValue = FindBestMatch($sOCRTextResult)

        WriteInLogs("ReadQuest: " & $sBestValue)
        Return $sBestValue
    EndIf
EndFunc  ;==>ReadQuest

Func LevenshteinDistance($s1, $s2)
    Local $len1 = StringLen($s1)
    Local $len2 = StringLen($s2)

    Local $matrix[$len1 + 1][$len2 + 1]

    For $i = 0 To $len1
        $matrix[$i][0] = $i
    Next
    For $j = 0 To $len2
        $matrix[0][$j] = $j
    Next

    For $i = 1 To $len1
        For $j = 1 To $len2
            Local $cost = 1
            If StringMid($s1, $i, 1) = StringMid($s2, $j, 1) Then $cost = 0

            $matrix[$i][$j] = Min($matrix[$i - 1][$j] + 1, _ 
                                  $matrix[$i][$j - 1] + 1, _ 
                                  $matrix[$i - 1][$j - 1] + $cost)
        Next
    Next

    Return $matrix[$len1][$len2]
EndFunc  ;==>LevenshteinDistance

Func Min($a, $b, $c)
    If $a < $b And $a < $c Then Return $a
    If $b < $c Then Return $b
    Return $c
EndFunc  ;==>Min
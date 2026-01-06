tell application "Notes"
    set query to "Twitter"
    set deletedNames to {"Recently Deleted", "Nylig slettet", "Zuletzt gelöscht", "Supprimés récemment", "Eliminados recientemente"}
    set noteDataList to {}
    
    repeat with f in folders
        set folderName to name of f
        if folderName is not in deletedNames then
            try
                set matchingInFolder to (notes of f whose name contains query or plaintext contains query)
                set matchCount to count of matchingInFolder
                if matchCount > 0 then
                    set idList to id of matchingInFolder
                    set nameList to name of matchingInFolder
                    repeat with i from 1 to matchCount
                        set end of noteDataList to (item i of idList) & "|" & folderName & "|" & (item i of nameList)
                    end repeat
                end if
            on error errMsg
                log "Error in folder " & folderName & ": " & errMsg
            end try
        end if
    end repeat
    
    set AppleScript's text item delimiters to (character id 10)
    return noteDataList as text
end tell

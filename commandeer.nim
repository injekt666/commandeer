
import parseopt2
import strutils
import tables


var
  argumentList = newSeq[ string ]()
  shortOptions = initTable[string, string](32)
  longOptions = initTable[string, string](32)
  argumentIndex = 0
  errorMsgs : seq[string] = @[]
  customErrorMsg : string

## String conversion
proc convert(s : string, t : char): char =
  result = s[0]
proc convert(s : string, t : int): int =
  result = parseInt(s)
proc convert(s : string, t : float): float =
  result = parseFloat(s)
proc convert(s : string, t : bool): bool =
  ## will accept "yes", "true" as true values
  if s == "":
    ## the only way we get an empty string here is because of a key
    ## with no value, in which case the presence of the key is enough
    ## to return true
    result = true
  else:
    result = parseBool(s)
proc convert(s : string, t : string): string =
    result = s.strip


template argument*(identifier : expr, t : typeDesc): stmt {.immediate.} =
  bind argumentList
  bind argumentIndex
  bind convert
  bind errorMsgs

  var identifier : t

  if argumentList.len <= argumentIndex:
    let eMsg = "Missing command line arguments"
    if len(errorMsgs) == 0:
      errorMsgs.add(eMsg)
    else:
      if not (errorMsgs[high(errorMsgs)][0] == 'M'):
        errorMsgs.add(eMsg)
  else:
    var typeVar : t
    try:
      identifier = convert(argumentList[argumentIndex], typeVar)
    except EInvalidValue:
      let eMsg = capitalize(getCurrentExceptionMsg()) &
                 " for argument " & $(argumentIndex+1)
      errorMsgs.add(eMsg)

  inc(argumentIndex)


template arguments*(identifier : expr, t : typeDesc, atLeast1 : bool = true): stmt {.immediate.} =
  bind argumentList
  bind argumentIndex
  bind convert
  bind errorMsgs

  var identifier = newSeq[t]()

  if atLeast1 and (argumentList.len <= argumentIndex):
    let eMsg = "Missing command line arguments"
    if len(errorMsgs) == 0:
      errorMsgs.add(eMsg)
    else:
      if not (errorMsgs[high(errorMsgs)][0] == 'M'):
        errorMsgs.add(eMsg)
  else:
    var typeVar : t
    var firstError = true
    while true:
      if argumentList.len == argumentIndex:
        break
      try:
        let a = argumentList[argumentIndex]
        inc(argumentIndex)
        identifier.add(convert(a, typeVar))
        firstError = false
      except EInvalidValue:
        if atLeast1 and firstError:
          let eMsg = capitalize(getCurrentExceptionMsg()) &
                     " for argument " & $(argumentIndex+1)
          errorMsgs.add(eMsg)
        break


template option*(identifier : expr, t : typeDesc, longName : string,
                 shortName : string): stmt {.immediate.} =
  bind shortOptions
  bind longOptions
  bind convert
  bind errorMsgs
  bind tables

  var identifier : t

  block:
    var typeVar : t
    if tables.hasKey(longOptions, longName):
      try:
        identifier = convert(tables.mget(longOptions, longName), typeVar)
      except EInvalidValue:
        let eMsg = capitalize(getCurrentExceptionMsg()) &
                   " for option --" & longName
        errorMsgs.add(eMsg)
    elif tables.hasKey(shortOptions, shortName):
      try:
        identifier = convert(tables.mget(shortOptions, shortName), typeVar)
      except EInvalidValue:
        let eMsg = capitalize(getCurrentExceptionMsg()) &
                   " for option -" & shortName
        errorMsgs.add(eMsg)


template exitoption*(longName, shortName, msg : string): stmt =
  bind shortOptions
  bind longOptions
  bind tables

  if tables.hasKey(longOptions, longName):
    quit msg, QuitSuccess
  elif tables.hasKey(shortOptions,  shortName):
    quit msg, QuitSuccess


template errormsg*(msg : string): stmt =
  bind customErrorMsg
  customErrorMsg = msg


template commandLine*(statements : stmt): stmt {.immediate.} =
  bind argumentList
  bind shortOptions
  bind longOptions
  bind errorMsgs
  bind parseopt2
  bind tables
  bind customErrorMsg

  for kind, key, value in parseopt2.getopt():
    case kind
    of parseopt2.cmdArgument:
      argumentList.add(key)
    of parseopt2.cmdLongOption:
      tables.add(longOptions, key, value)
    of parseopt2.cmdShortOption:
      tables.add(shortOptions, key, value)
    else:
      discard

  #Call the passed statements so that the above templates are called
  statements

  if not customErrorMsg.isNil:
    errorMsgs.add(customErrorMsg)

  if len(errorMsgs) > 0:
    quit join(errorMsgs, "\n")


when isMainModule:
  import unittest

  test "convert() returns converted type value from strings":
    var intVar : int
    var floatVar : float
    var boolVar : bool
    var stringVar : string
    var charVar : char

    check convert("10", intVar) == 10
    check convert("10.0", floatVar) == 10
    check convert("10", floatVar) == 10
    check convert("yes", boolVar) == true
    check convert("false", boolVar) == false
    check convert("no ", stringVar) == "no"
    check convert("*", charVar) == '*'

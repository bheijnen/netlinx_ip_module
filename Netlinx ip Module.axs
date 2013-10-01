(DEV vdvVirtual, DEV dvDevice)
(***********************************************************)
(***********************************************************)
(*  FILE_LAST_MODIFIED_ON: 04/04/2006  AT: 11:33:16        *)
(***********************************************************)
(* System Type : NetLinx                                   *)
(***********************************************************)
(* REV HISTORY:                                            *)
(***********************************************************)
(*
    $History: $
*)    
(***********************************************************)
(*          DEVICE NUMBER DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_DEVICE

(***********************************************************)
(*               CONSTANT DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_CONSTANT
TIMELINE_ID_1				=	   1
MAX_BUFFER_LENGTH			=	3000

/*	COMMAND CONSTANTS	*/
COMMAND_INTERVAL			=	1000
MAX_BUFFER_COMMANDS			=	 300
MAX_COMMAND_LENGTH			=	  30
CMD_SET_PROPERTY			=	   1
CMD_GET_PROPERTY			=	   2
CMD_SET_LOG				=	   3
CMD_GET_LOG				=	   4
CHAR acCommands[][MAX_COMMAND_LENGTH]	= { 'PROPERTY', '?PROPERTY', 'LOG', '?LOG' }

MAX_PROPNAME_LENGTH			=	  30
MAX_PROPVAL_LENGTH			=	  30
PROPERTY_HOSTNAME			=	   1
PROPERTY_IPADDRESS			=	   2
PROPERTY_IPPORT				=	   3
PROPERTY_USERNAME			=	   4
PROPERTY_PASSWORD			=	   5
PROPERTY_POLLINTERVAL			=	   6
CHAR acProperties[][MAX_PROPNAME_LENGTH]= { 'hostname', 'ipaddress', 'ipport', 'username', 'password', 'pollinterval'}

CHAR acLogLevels[][8] = {'error', 'warning', 'info', 'debug'}

MAX_IPADDRESS_LENGTH		=	  15
MAX_USERNAME_LENGTH		=	  63
MAX_PASSWORD_LENGTH		=	  63
MAX_HOSTNAME_LENGTH 		=	  63 	// what is the maximum length of a hostname ???

MON_PWR_OFF	=	0
MON_PWR_ON	=	1

SLONG IP_STATUS_UNKNOWN	=      -1

#INCLUDE 'SNAPI.axi'
(***********************************************************)
(*              DATA TYPE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_TYPE
STRUCTURE _uIpDevice
{
    CHAR acHostname[MAX_HOSTNAME_LENGTH]	// what is the maximum length of a hostname ???
    CHAR acIpAddress[MAX_IPADDRESS_LENGTH]
    INTEGER nIpPort
}
STRUCTURE _uUser
{
    CHAR acUsername[MAX_USERNAME_LENGTH]
    CHAR acPassword[MAX_PASSWORD_LENGTH]
}

(***********************************************************)
(*               VARIABLE DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_VARIABLE
VOLATILE _uIpDevice uIpDevice
VOLATILE _uUser uUser
VOLATILE CHAR acBuffer[MAX_BUFFER_LENGTH]
VOLATILE LONG lTimeArray[] 		= 	  {0,COMMAND_INTERVAL}
VOLATILE INTEGER nTxWrite, nTxRead
VOLATILE CHAR acCommandBuffer[MAX_BUFFER_COMMANDS][MAX_COMMAND_LENGTH]
VOLATILE SLONG slIpConnection
VOLATILE CHAR acPollRequest[] = ''
VOLATILE CHAR acServerAddress[MAX_HOSTNAME_LENGTH]
(***********************************************************)
(*               LATCHING DEFINITIONS GO BELOW             *)
(***********************************************************)
DEFINE_LATCHING

(***********************************************************)
(*       MUTUALLY EXCLUSIVE DEFINITIONS GO BELOW           *)
(***********************************************************)
DEFINE_MUTUALLY_EXCLUSIVE

(***********************************************************)
(*        SUBROUTINE/FUNCTION DEFINITIONS GO BELOW         *)
(***********************************************************)
(* EXAMPLE: DEFINE_FUNCTION <RETURN_TYPE> <NAME> (<PARAMETERS>) *)
(* EXAMPLE: DEFINE_CALL '<NAME>' (<PARAMETERS>) *)
DEFINE_FUNCTION CHAR[100] GET_IP_ERROR (LONG lIpError)
{
    SWITCH (lIpError) {
	CASE 0:
	  RETURN "";
	CASE 2:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): General Failure (IP_CLIENT_OPEN/IP_SERVER_OPEN)'";
	CASE 4:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): unknown host or DNS error (IP_CLIENT_OPEN)'";
	CASE 6:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): connection refused (IP_CLIENT_OPEN)'";
	CASE 7:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): connection timed out (IP_CLIENT_OPEN)'";
	CASE 8:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): unknown connection error (IP_CLIENT_OPEN)'";
	CASE 14:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): local port already used (IP_CLIENT_OPEN/IP_SERVER_OPEN)'";
	CASE 16:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): too many open sockets (IP_CLIENT_OPEN/IP_SERVER_OPEN)'";
	CASE 10:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): Binding error (IP_SERVER_OPEN)'";
	CASE 11:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): Listening error (IP_SERVER_OPEN)'";
	CASE 15:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): UDP socket already listening (IP_SERVER_OPEN)'";
	CASE 9:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): Already closed (IP_CLIENT_CLOSE/IP_SERVER_CLOSE)'";
	CASE 17:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): Local port not open, can not send string (IP_CLIENT_OPEN)'";	
	DEFAULT:
	  RETURN "'IP ERROR (',ITOA(lIpError),'): Unknown'";
    }
}

DEFINE_FUNCTION fnAddTxBuffer(CHAR acData[])
{
    IF(((nTxWrite % MAX_BUFFER_COMMANDS) + 1) ==  nTxRead) {
	// this will overwrite data!!!
	AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': this will overwrite data!!! Please increase send speed to real device'")
	AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': or increase buffer size MAX_COMMANDS'")
    }
    ELSE {
	IF(LENGTH_STRING(MAX_COMMAND_LENGTH) > MAX_COMMAND_LENGTH) {
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': this command length(',ITOA(LENGTH_STRING(MAX_COMMAND_LENGTH)),') doesnt fit!!! Please increase buffer entry length'")
	}
	ELSE {
	    acCommandBuffer[nTxWrite] = "acData"
	    nTxWrite = (nTxWrite % MAX_BUFFER_COMMANDS) + 1
	}
    }
}

DEFINE_FUNCTION fnParseCommand(INTEGER nCmdIdx, CHAR acValue[]) {
    SWITCH(nCmdIdx) {
	CASE CMD_SET_PROPERTY:
	    fnParseSetProperty(acValue)
	    BREAK;
	CASE CMD_GET_PROPERTY:
	    fnParseGetProperty(acValue)
	    BREAK;
	CASE CMD_SET_LOG:
	    fnParseSetLogLevel(acValue)
	    BREAK;
	CASE CMD_GET_LOG:
	    fnParseGetLogLevel()
	    BREAK;
	DEFAULT:
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': fnParseCommand(',ITOA(nCmdIdx),') unhandled'")
	    BREAK;
    }
}

    DEFINE_FUNCTION fnParseSetProperty(CHAR acPropertyString[])
{
    CHAR acPropertyName[MAX_PROPNAME_LENGTH]
    CHAR acPropertyValue[MAX_PROPVAL_LENGTH]
    INTEGER nIdx
    
    acPropertyName = REMOVE_STRING(acPropertyString,':', 1)
    SET_LENGTH_STRING(acPropertyName, LENGTH_STRING(acPropertyName)-1)
    acPropertyName = LOWER_STRING(acPropertyName)
    acPropertyValue = acPropertyString
    
    FOR(nIdx = 1; nIdx <= LENGTH_ARRAY(acProperties); nIdx++) {
	IF(acProperties[nIdx] == acPropertyName) {
	    BREAK;
	}
    }
    
    SWITCH(nIdx) {
	CASE PROPERTY_HOSTNAME:
	    IF(fnSetPropertyHostname(acPropertyValue)) {
		SEND_STRING vdvVirtual,"'invalid hostname'"
	    }
	    BREAK;
	CASE PROPERTY_IPADDRESS:
	    IF(fnSetPropertyIpAddress(acPropertyValue)) {
		SEND_STRING vdvVirtual,"'invalid ip address'"
	    }
	    BREAK;
	CASE PROPERTY_IPPORT:
	    IF(fnSetPropertyIpPort(acPropertyValue))
	    {
		SEND_STRING vdvVirtual,"'invalid ip port'"
	    }
	    BREAK;
	CASE PROPERTY_USERNAME:
	    IF(fnSetPropertyUsername(acPropertyValue))
	    {
		SEND_STRING vdvVirtual,"'invalid username'"
	    }
	    BREAK;
	CASE PROPERTY_PASSWORD:
	    IF(fnSetPropertyPassword(acPropertyValue))
	    {
		SEND_STRING vdvVirtual,"'invalid password'"
	    }
	    BREAK;
	CASE PROPERTY_POLLINTERVAL:
	    IF(fnSetPropertyPollInterval(acPropertyValue))
	    {
		SEND_STRING vdvVirtual,"'invalid ip port'"
	    }
	    BREAK;
	DEFAULT:
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': fnParseSetProperty(',acPropertyString,') unhandled'")
	    BREAK;
    }
}
	DEFINE_FUNCTION INTEGER fnSetPropertyHostname(CHAR acHostname[])
{
    INTEGER nResult

    IF(LENGTH_STRING(acHostname) > 0 && LENGTH_STRING(acHostname) <= MAX_HOSTNAME_LENGTH) {
	// what character would be allowed in a hostname????
	IF(FIND_STRING(acHostname,' ', 1)) {
	    // no spaces allowed in hostname
	    nResult = 2
	}
	ELSE {
	    // store ip adress
	    uIpDevice.acHostname = acHostname
	    
	    // reinit connection with new ip address
	    IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
		IP_CLIENT_CLOSE(dvDevice.PORT)
	    }
	}
    }
    ELSE {
	// length boundary invalid
	nResult = 1
    }
    
    RETURN nResult
}
	DEFINE_FUNCTION INTEGER fnSetPropertyIpAddress(CHAR acIpAddress[])
{
    INTEGER nResult
    INTEGER nIdx
    INTEGER nField[4]
    CHAR acNewIpAddress[MAX_IPADDRESS_LENGTH]

    acNewIpAddress = acIpAddress
    IF(LENGTH_STRING(acIpAddress) > 0) {
	IF(FIND_STRING(acIpAddress,'.',1)) {
	    nField[1] = ATOI(REMOVE_STRING(acIpAddress,'.',1))
	    IF(FIND_STRING(acIpAddress,'.',1)) {
		nField[2] = ATOI(REMOVE_STRING(acIpAddress,'.',1))
		IF(FIND_STRING(acIpAddress,'.',1)) {
		    nField[3] = ATOI(REMOVE_STRING(acIpAddress,'.',1))
		    nField[4] = ATOI(acIpAddress)
		}
	    }
	}
	
	FOR(nIdx = 1; nIdx <= 4; nIdx++) {
	    IF(nField[nIdx] > 254) {
		BREAK;
	    }
	}
	
	IF(nIdx == 5) {
	    // store ip adress
	    uIpDevice.acIpAddress = acNewIpAddress
	    
	    // reinit connection with new ip address
	    IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
		IP_CLIENT_CLOSE(dvDevice.PORT)
	    }
	}
	ELSE {
	    // one or more fields not within limits
	    nResult = 2
	}
    }
    ELSE {
	// no length
	nResult = 1
    }
    
    RETURN nResult
}
	DEFINE_FUNCTION INTEGER fnSetPropertyIpPort(CHAR acIpPort[])
{
    INTEGER nValue
    INTEGER nResult

    nValue = ATOI(acIpPort)
    IF(nValue >= 100 && nValue <= 100000) {
	// store ip port
	uIpDevice.nIpPort = ATOI(acIpPort)
	
	// reinit connection with new ip port
	IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
	    IP_CLIENT_CLOSE(dvDevice.PORT)
	}
    }
    ELSE {
	// port number out of bounds
	nResult = 1
    }
    
    RETURN nResult
}
	DEFINE_FUNCTION INTEGER fnSetPropertyUsername(CHAR acUsername[])
{
    INTEGER nResult

    IF(LENGTH_STRING(acUsername) < 64) {
	// store username
	uUser.acUsername = acUsername
	
	// reinit connection with new ip port
	IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
	    IP_CLIENT_CLOSE(dvDevice.PORT)
	}
    }
    ELSE {
	// port number out of bounds
	nResult = 1
    }
    
    RETURN nResult
}
	DEFINE_FUNCTION INTEGER fnSetPropertyPassword(CHAR acPassword[])
{
    INTEGER nResult

    IF(LENGTH_STRING(acPassword) < 64) {
	// store username
	uUser.acPassword = acPassword
	
	// reinit connection with new ip port
	IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
	    IP_CLIENT_CLOSE(dvDevice.PORT)
	}
    }
    ELSE {
	// port number out of bounds
	nResult = 1
    }
    
    RETURN nResult
}
	DEFINE_FUNCTION INTEGER fnSetPropertyPollInterval(CHAR acPollInterval[])
{
    INTEGER nValue
    INTEGER nResult

    nValue = ATOI(acPollInterval)
    IF(nValue >= 100 && nValue <= 10000) {
	lTimeArray[1] = nValue
	TIMELINE_RELOAD(TIMELINE_ID_1, lTimeArray, LENGTH_ARRAY(lTimeArray))
    }
    ELSE {
	// pollinterval out of bounds
	nResult = 1
    }
    
    RETURN nResult
}
    DEFINE_FUNCTION fnParseGetProperty(CHAR acPropertyString[])
{
    CHAR acPropertyName[MAX_PROPNAME_LENGTH]
    CHAR acPropertyValue[MAX_PROPVAL_LENGTH]
    INTEGER nIdx
    
    acPropertyName = REMOVE_STRING(acPropertyString,':', 1)
    SET_LENGTH_STRING(acPropertyName, LENGTH_STRING(acPropertyName)-1)
    acPropertyName = LOWER_STRING(acPropertyName)
    acPropertyValue = acPropertyString
    
    FOR(nIdx = 1; nIdx <= LENGTH_ARRAY(acProperties); nIdx++) {
	IF(acProperties[nIdx] == acPropertyName) {
	    BREAK;
	}
    }
    
    SWITCH(nIdx) {
	CASE PROPERTY_HOSTNAME:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',uIpDevice.acHostname"
	    BREAK;
	CASE PROPERTY_IPADDRESS:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',uIpDevice.acIpAddress"
	    BREAK;
	CASE PROPERTY_IPPORT:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',ITOA(uIpDevice.nIpPort)"
	    BREAK;
	CASE PROPERTY_USERNAME:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',uUser.acUsername"
	    BREAK;
	CASE PROPERTY_PASSWORD:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',uUser.acPassword"
	    BREAK;
	CASE PROPERTY_POLLINTERVAL:
	    SEND_STRING vdvVirtual,"'PROPERTY-',acPropertyName,':',ITOA(lTimeArray[1])"
	    BREAK;
	DEFAULT:
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': fnParseGetProperty(',acPropertyString,') unhandled'")
	    BREAK;
    }
}
    DEFINE_FUNCTION fnParseSetLogLevel(CHAR acSetLogLevel[])
{
    INTEGER nIdx
    
    acSetLogLevel = LOWER_STRING(acSetLogLevel)
    FOR(nIdx = 1; nIdx <= LENGTH_ARRAY(acLogLevels); nIdx++) {
	IF(acLogLevels[nIdx] == acSetLogLevel) {
	    BREAK;
	}
    }
    
    IF(nIdx <= LENGTH_ARRAY(acLogLevels)) {
	SWITCH(nIdx) {
	    CASE AMX_ERROR:
	    CASE AMX_WARNING:
	    CASE AMX_INFO:
	    CASE AMX_DEBUG:
		SET_LOG_LEVEL(nIdx)
		BREAK;
	}
    }
    ELSE {
	SEND_STRING 0,"'unsupported log level type: ', acSetLogLevel"
    }
}
    DEFINE_FUNCTION fnParseGetLogLevel()
{
    SEND_STRING vdvVirtual,"'LOG-',acLogLevels[GET_LOG_LEVEL()]"
}

    DEFINE_FUNCTION fnSetPower(INTEGER nPower)
{
    SWITCH(nPower) {
	CASE MON_PWR_ON:
	    fnAddTxBuffer("'on'")
	    BREAK;
	CASE MON_PWR_OFF:
	    fnAddTxBuffer("'off'")
	    BREAK;
	DEFAULT:
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,' undefined powerstate fnPower nPower: ', ITOA(nPower)")
	    BREAK;
    }
}

(***********************************************************)
(*                STARTUP CODE GOES BELOW                  *)
(***********************************************************)
DEFINE_START
TIMELINE_CREATE(TIMELINE_ID_1, lTimeArray, LENGTH_ARRAY(lTimeArray), TIMELINE_ABSOLUTE, TIMELINE_REPEAT)
CREATE_BUFFER dvDevice, acBuffer
nTxRead  = 1
nTxWrite = 1

(***********************************************************)
(*                THE EVENTS GO BELOW                      *)
(***********************************************************)
DEFINE_EVENT
DATA_EVENT[dvDevice]
{
    ONLINE:
    {
	ON[vdvVirtual, DEVICE_COMMUNICATING]
	AMX_LOG(AMX_DEBUG,"'mdl ',__FILE__,': device online'")
    }
    STRING:
    {
	AMX_LOG(AMX_DEBUG,"'mdl ',__FILE__,': received (',acBuffer,') unhandled'")
	CLEAR_BUFFER acBuffer
    }
    ONERROR:
    {
	AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': ip error(',GET_IP_ERROR(DATA.NUMBER),')'")
	slIpConnection = TYPE_CAST(DATA.NUMBER)
    }
    OFFLINE:
    {
	slIpConnection = -1
	OFF[vdvVirtual, DEVICE_COMMUNICATING]
	AMX_LOG(AMX_DEBUG,"'mdl ',__FILE__,': device online'")
    }
}

DATA_EVENT[vdvVirtual]
{
    ONLINE:
    {
	slIpConnection = IP_STATUS_UNKNOWN
    }
    COMMAND:
    {
	CHAR acCommand[MAX_COMMAND_LENGTH]
	INTEGER nIdx
	
	// get CMD
	IF(FIND_STRING(DATA.TEXT,'?',1)) {
	    acCommand = DATA.TEXT
	}
	ELSE IF(FIND_STRING(DATA.TEXT,'-',1)) {
	    acCommand = REMOVE_STRING(DATA.TEXT,'-',1)
	    SET_LENGTH_STRING(acCommand, LENGTH_STRING(acCommand)-1)
	}
	
	// lookup and execute
	FOR(nIdx = 1; nIdx <= LENGTH_ARRAY(acCommands); nIdx++) {
	    IF(FIND_STRING(acCommands[nIdx],"acCommand", 1)) {
		fnParseCommand(nIdx, DATA.TEXT)
		BREAK;
	    }
	}
	
	IF(nIdx > LENGTH_ARRAY(acCommands)) {
	    AMX_LOG(AMX_ERROR,"'mdl ',__FILE__,': command (',acCommand,') unhandled'")
	}
    }
}

TIMELINE_EVENT[TIMELINE_ID_1]
{
    SWITCH(TIMELINE.SEQUENCE) {
	CASE 1:
	    IF([vdvVirtual, DEVICE_COMMUNICATING] == TRUE) {
		IF(nTxRead != nTxWrite) {
		    AMX_LOG(AMX_DEBUG,"acCommandBuffer[nTxRead]")
		    SEND_STRING dvDevice,"acCommandBuffer[nTxRead]"
		    nTxRead = (nTxRead % MAX_BUFFER_COMMANDS) + 1
		}
		ELSE {
		    IF(LENGTH_STRING(acPollRequest) && !(TIMELINE.REPETITION % 10)) { // once every 10 seconds if connection is up
			AMX_LOG(AMX_DEBUG,"acPollRequest")
			SEND_STRING dvDevice,"acPollRequest,13,10"
		    }
		}
	    }
	    ELSE {
		IF(LENGTH_STRING(uIpDevice.acHostname)) {
		    acServerAddress = uIpDevice.acHostname
		}
		ELSE IF(LENGTH_STRING(uIpDevice.acIpAddress)) {
		    acServerAddress = uIpDevice.acIpAddress
		}
		
		IF(LENGTH_STRING(acServerAddress) && uIpDevice.nIpPort > 0) {
		    // validate ip address and port
		    IF(slIpConnection) {
			// only open if not already online and returned an error
			slIpConnection = IP_CLIENT_OPEN(dvDevice.PORT, acServerAddress, uIpDevice.nIpPort, IP_TCP)
		    }
		}
	    }
	    BREAK;
    }
}
(***********************************************************)
(*            THE ACTUAL PROGRAM GOES BELOW                *)
(***********************************************************)
DEFINE_PROGRAM

(***********************************************************)
(*                     END OF PROGRAM                      *)
(*        DO NOT PUT ANY CODE BELOW THIS COMMENT           *)
(***********************************************************)

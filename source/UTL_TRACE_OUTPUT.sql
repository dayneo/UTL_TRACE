create table UTL_TRACE_OUTPUT
(
	OWNER         varchar2(4000)                              not null,
	RUNID         varchar2(4000)                              not null,
	SEQ           number                                      not null,
	TRACE_TS      timestamp      default systimestamp         not null,
	ORA_USER      varchar2(4000) default user                 not null,
	ORA_SESSIONID number         default userenv('SESSIONID') not null,
	PROC_OWNER    varchar2(255),
	PROC_NAME     varchar2(255),
	PROC_LINE     number,
	MSG_PART      varchar2(4000),
	XML_DATA      XMLType,
	CLOB_DATA     CLOB,
	BLOB_DATA     BLOB
)
/
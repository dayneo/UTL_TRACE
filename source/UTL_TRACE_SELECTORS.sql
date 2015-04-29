create table UTL_TRACE_SELECTORS
(
	OWNER     varchar2(255) default user not null,
	RUNID     varchar2(255)              not null,
	ORA_USER  varchar2(255),
	SESSIONID number,
	MODULES   varchar2(4000),
	constraint UTL_TRACE_SELECTORS_PK primary key (OWNER, RUNID)
)
CACHE
/
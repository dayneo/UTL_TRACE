create or replace package UTL_TRACE as

	type Argv is table of varchar2(4000);
	EMPTY_ARGV Argv;

	--
	-- Starts the trace session
	--
	procedure init
	(
		p_modules     in     varchar2 default 'ALL',
		p_user        in     varchar2 default user,
		p_sessionid   in     number   default null
	);
	
	procedure init
	(
		p_runid       in out varchar2,
		p_modules     in     varchar2 default 'ALL',
		p_user        in     varchar2 default user,
		p_sessionid   in     number   default null
	);
	
	--
	-- Ends the trace session
	--
	procedure clear(p_runid in varchar2 default null);
	
	--
	-- Outputs trace information by replacing numeric tags in the message with
	-- the corresponding p_argn value
	--
	procedure f
	(
		p_message in varchar2,
		p_arg1    in varchar2 default null,
		p_arg2    in varchar2 default null,
		p_arg3    in varchar2 default null,
		p_arg4    in varchar2 default null,
		p_arg5    in varchar2 default null,
		p_arg6    in varchar2 default null,
		p_arg7    in varchar2 default null,
		p_arg8    in varchar2 default null,
		p_arg9    in varchar2 default null,
		p_arg10   in varchar2 default null
	);
	
	procedure f
	(
		p_message in varchar2,
		p_arg1    in varchar2 default null,
		p_arg2    in varchar2 default null,
		p_arg3    in varchar2 default null,
		p_arg4    in varchar2 default null,
		p_arg5    in varchar2 default null,
		p_arg6    in varchar2 default null,
		p_arg7    in varchar2 default null,
		p_arg8    in varchar2 default null,
		p_arg9    in varchar2 default null,
		p_arg10   in varchar2 default null,
		p_data    in xmltype
	);

	procedure f
	(
		p_message in varchar2,
		p_arg1    in varchar2 default null,
		p_arg2    in varchar2 default null,
		p_arg3    in varchar2 default null,
		p_arg4    in varchar2 default null,
		p_arg5    in varchar2 default null,
		p_arg6    in varchar2 default null,
		p_arg7    in varchar2 default null,
		p_arg8    in varchar2 default null,
		p_arg9    in varchar2 default null,
		p_arg10   in varchar2 default null,
		p_data    in clob
	);
		
	procedure f
	(
		p_message in varchar2,
		p_arg1    in varchar2 default null,
		p_arg2    in varchar2 default null,
		p_arg3    in varchar2 default null,
		p_arg4    in varchar2 default null,
		p_arg5    in varchar2 default null,
		p_arg6    in varchar2 default null,
		p_arg7    in varchar2 default null,
		p_arg8    in varchar2 default null,
		p_arg9    in varchar2 default null,
		p_arg10   in varchar2 default null,
		p_data    in blob 
	);
	
	--
	-- Outputs trace information by replacing numeric tags in the message with
	-- the corresponding p_args(n) value
	--
	procedure f
	(
		p_message in varchar2,
		p_args    in Argv 
	);

end UTL_TRACE;
/
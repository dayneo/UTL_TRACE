create or replace package body UTL_TRACE as

	Ctrl constant varchar2(2) := chr(10);
	
	type caller_record is record
	(
		proc_owner varchar2(255) default user,
		proc_name  varchar2(255) default 'ANONYMOUS BLOCK',
		proc_line  number
	);

	g_session_id varchar2(32767);

	--
	-- Procedure: WHO_CALLED_ME
	-- Provides information on what called the procedure 
	--
	procedure who_called_me(p_caller out caller_record) is

		l_call_stack long default dbms_utility.format_call_stack;
		l_line       varchar2(4000);
		
	begin

		for i in 1 .. 6 loop
		
			l_call_stack := substr(
				l_call_stack, 
				instr(l_call_stack, chr(10)) + 1
			);
                    
		end loop;
 
		l_line := ltrim(
			substr(
				l_call_stack, 
				1, 
				instr(l_call_stack, chr(10)) - 1
			)
		);
 
		l_line := ltrim(substr(l_line, instr(l_line, ' ')));
 
		p_caller.proc_line := to_number(substr(l_line, 1, instr(l_line, ' ')));
		l_line := ltrim(substr(l_line, instr(l_line, ' ')));
 		l_line := ltrim(substr(l_line, instr(l_line, ' ')));
 
		if l_line like 'block%' or
		   l_line like 'body%' then
			
			l_line := ltrim(substr(l_line, instr(l_line, ' ')));
			
		end if;
 
		p_caller.proc_owner := ltrim(rtrim(
			substr(
				l_line,
				1,
				instr(l_line, '.') - 1
			)
		));
		
		p_caller.proc_name := ltrim(rtrim(
			substr(
				l_line,
				instr(l_line, '.') + 1
			)
		));
 
		if p_caller.proc_owner is null then
		
			p_caller.proc_owner := user;
			p_caller.proc_name := 'ANONYMOUS BLOCK';
			
		end if;

	end who_called_me;

	--
	-- Function: PARSE_IT
	-- Returns the result of replacing message tags with values
	--
	function parse_it
	(
		p_message       in varchar2,
		p_argv          in argv,
		p_header_length in number default 0
	) return varchar2 is

		l_message long := null;
		l_str     long := p_message;
		l_idx     number := 1;
		l_ptr     number := 1;
		
	begin

		if nvl(instr(p_message, '%' ), 0) = 0 and
		   nvl(instr(p_message, '\' ), 0) = 0 then
		   
			return p_message;
			
		end if;
 
		loop
 
			l_ptr := instr(l_str, '%');
			exit when l_ptr = 0 or l_ptr is null;
			l_message := l_message || substr(l_str, 1, l_ptr - 1);
			l_str := substr(l_str, l_ptr + 1);

			if substr(l_str, 1, 1) = 's' then
			
				l_message := l_message || p_argv(l_idx);
				l_idx := l_idx + 1;
				l_str := substr(l_str, 2);
 
			elsif substr(l_str, 1, 1) = '%' then
			
				l_message := l_message || '%';
				l_str := substr(l_str, 2);
 
			else
			
				l_message := l_message || '%';
				
			end if;
 
		end loop;
 
		l_str := l_message || l_str;
		l_message := null;
 
		loop
 
			l_ptr := instr( l_str, '\' );
			exit when l_ptr = 0 or l_ptr is null;
			l_message := l_message || substr(l_str, 1, l_ptr - 1);
			l_str :=  substr( l_str, l_ptr+1 );
 
			if substr(l_str, 1, 1) = 'n' then
			
				l_message := l_message || chr(10) || rpad(' ', p_header_length, ' ');
				l_str := substr(l_str, 2);
 
			elsif substr(l_str, 1, 1) = 't' then
			
				l_message := l_message || chr(9);
				l_str := substr(l_str, 2);
 
			elsif substr(l_str, 1, 1) = '\' then
			
				l_message := l_message || '\';
				l_str := substr(l_str, 2);
 
			else
			
				l_message := l_message || '\';
				
			end if;
 
		end loop;

		return l_message || l_str;

	end parse_it;

	--
	-- Function: FILE_IT
	-- Writes the message to the output destination
	--
	procedure file_it(p_selector in utl_trace_selectors%rowtype, p_message in varchar2) is
		
		l_seq number;
	
	begin

		insert into utl_trace_output
		(
			owner,
			runid,
			seq,
			msg_part
		) 
		select 
			p_selector.owner,
			p_selector.runid,
			utl_trace_output_seq.nextval,
			p_message
		from dual;
			
	end file_it;

	--
	-- Function: FILE_IT
	-- Writes the message to the output destination
	--
	function file_it
	(
		p_selector in utl_trace_selectors%rowtype, 
		p_caller   in caller_record, 
		p_message  in varchar2,
		p_xml      in xmltype default null,
		p_clob     in clob    default null,
		p_blob     in blob    default null
	) return boolean is
		pragma AUTONOMOUS_TRANSACTION;
		
		l_seq number;
	
	begin

		insert into utl_trace_output
		(
			owner,
			runid,
			seq,
			proc_owner,
			proc_name,
			proc_line,
			msg_part,
			xml_data,
			clob_data,
			blob_data
		) 
		select 
			p_selector.owner,
			p_selector.runid,
			utl_trace_output_seq.nextval,
			p_caller.proc_owner,
			p_caller.proc_name,
			p_caller.proc_line,
			p_message,
			p_xml,
			p_clob,
			p_blob
		from dual;

		commit;
		
		return true;
				
	exception 
		when OTHERS then
			rollback;
			return false;
			
	end file_it;

	--
	-- Procedure: DEBUG_IT
	-- Decide whether or not to output values
	--
	procedure debug_it
	(
		p_message in varchar2,
		p_argv    in argv,
		p_xml     in xmltype default null,
		p_clob    in clob    default null,
		p_blob    in blob    default null
	) is

		l_message          long := null;
		call_who_called_me boolean := true;
		l_caller           caller_record;
		l_dummy            boolean;
		
	begin

		for l_selector in (select * from utl_trace_selectors where ora_user = user) loop

			if call_who_called_me then
			
				who_called_me(l_caller);
				call_who_called_me := false;
				
			end if;

			if l_selector.modules = 'ALL' 
			   or instr(',' || l_selector.modules || ',', ',' || l_caller.proc_name || ',' ) <> 0
			   then

				l_message := parse_it(p_message, p_argv);
				l_dummy   := file_it(l_selector, l_caller, l_message, p_xml, p_clob, p_blob);

			end if;
			
		end loop;
		
	end debug_it;

	procedure init
	(
		p_modules     in     varchar2 default 'ALL',
		p_user        in     varchar2 default user,
		p_sessionid   in     number   default null
	) is
		pragma AUTONOMOUS_TRANSACTION;
		
		l_selector utl_trace_selectors%rowtype;
		l_message  long;
		
	begin
	
		delete from utl_trace_selectors where owner = user;
 
		insert into utl_trace_selectors
		(
			runid,
			ora_user,
			sessionid,
			modules
		)
		values 
		(
			sys_guid(),
			p_user,
			p_sessionid,
			p_modules
		)
		returning 
			owner, 
			runid, 
			ora_user, 
			sessionid, 
			modules 
		into 
			l_selector.owner, 
			l_selector.runid, 
			l_selector.ora_user, 
			l_selector.sessionid, 
			l_selector.modules;

		l_message := 
			chr(10) || 
			'Trace initialized @ ' || to_char(sysdate, 'dd-MON-yyyy hh24:mi:ss' ) || ' for ' || chr(10) ||
			'SESSIONID: ' || l_selector.sessionid                                            || chr(10) || 
			'     USER: ' || l_selector.ora_user                                             || chr(10) || 
			'  MODULES: ' || l_selector.modules                                              || chr(10);

		file_it(l_selector, l_message);
 
		commit;

	exception
		when OTHERS then
			rollback;
			RAISE_APPLICATION_ERROR(
				-20001,
				'Can not write trace',
				TRUE
			);
			
	end init;

	procedure init
	(
		p_runid       in out varchar2,
		p_modules     in     varchar2 default 'ALL',
		p_user        in     varchar2 default user,
		p_sessionid   in     number   default null
	) is
		pragma AUTONOMOUS_TRANSACTION;
		
		l_selector utl_trace_selectors%rowtype;
		l_message  long;
 
	begin

		if p_runid is null then
		
			p_runid := sys_guid();
			
		end if;

		delete from utl_trace_selectors where owner = user and runid = p_runid;
 
		insert into utl_trace_selectors
		(
			runid,
			ora_user,
			sessionid,
			modules
		)
		values 
		(
			p_runid,
			p_user,
			p_sessionid,
			p_modules
		)
		returning 
			owner, 
			runid, 
			ora_user, 
			sessionid, 
			modules 
		into 
			l_selector.owner, 
			l_selector.runid, 
			l_selector.ora_user, 
			l_selector.sessionid, 
			l_selector.modules;

		l_message := 
			chr(10) || 
			'Trace initialized @ ' || to_char(sysdate, 'dd-MON-yyyy hh24:mi:ss' ) || ' for ' || chr(10) ||
			'SESSIONID: ' || l_selector.sessionid                                            || chr(10) || 
			'     USER: ' || l_selector.ora_user                                             || chr(10) || 
			'  MODULES: ' || l_selector.modules                                              || chr(10);

		file_it(l_selector, l_message);
 
		commit;

	exception
		when OTHERS then
			rollback;
			RAISE_APPLICATION_ERROR(
				-20001,
				'Can not write trace',
				TRUE
			);

	end init;

	procedure clear(p_runid in varchar2 default null) is
		pragma autonomous_transaction;

		l_message varchar2(4000);
		
	begin
	
		delete from utl_trace_selectors where owner = user and runid = nvl(p_runid, runid);
		commit;
		
	end clear; 
	
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
	) is
	begin

		debug_it
		(
			p_message,
			argv(
				substr(p_arg1, 1, 4000),
				substr(p_arg2, 1, 4000),
				substr(p_arg3, 1, 4000),
				substr(p_arg4, 1, 4000),
				substr(p_arg5, 1, 4000),
				substr(p_arg6, 1, 4000),
				substr(p_arg7, 1, 4000),
				substr(p_arg8, 1, 4000),
				substr(p_arg9, 1, 4000),
				substr(p_arg10, 1, 4000) 
			)
		);

	end f;
	
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
	) is
	begin

		debug_it
		(
			p_message,
			argv(
				substr(p_arg1, 1, 4000),
				substr(p_arg2, 1, 4000),
				substr(p_arg3, 1, 4000),
				substr(p_arg4, 1, 4000),
				substr(p_arg5, 1, 4000),
				substr(p_arg6, 1, 4000),
				substr(p_arg7, 1, 4000),
				substr(p_arg8, 1, 4000),
				substr(p_arg9, 1, 4000),
				substr(p_arg10, 1, 4000) 
			),
			p_xml=>p_data
		);

	end f;

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
	) is
	begin

		debug_it
		(
			p_message,
			argv(
				substr(p_arg1, 1, 4000),
				substr(p_arg2, 1, 4000),
				substr(p_arg3, 1, 4000),
				substr(p_arg4, 1, 4000),
				substr(p_arg5, 1, 4000),
				substr(p_arg6, 1, 4000),
				substr(p_arg7, 1, 4000),
				substr(p_arg8, 1, 4000),
				substr(p_arg9, 1, 4000),
				substr(p_arg10, 1, 4000) 
			),
			p_clob=>p_data
		);

	end f;
	
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
	) is
	begin

		debug_it
		(
			p_message,
			argv(
				substr(p_arg1, 1, 4000),
				substr(p_arg2, 1, 4000),
				substr(p_arg3, 1, 4000),
				substr(p_arg4, 1, 4000),
				substr(p_arg5, 1, 4000),
				substr(p_arg6, 1, 4000),
				substr(p_arg7, 1, 4000),
				substr(p_arg8, 1, 4000),
				substr(p_arg9, 1, 4000),
				substr(p_arg10, 1, 4000) 
			),
			p_blob=>p_data
		);

	end f;

	procedure f
	(
		p_message in varchar2,
		p_args    in Argv
	) is
	begin

		debug_it(p_message, p_args);

	end f;

--	procedure status(
--	  p_user in varchar2 default user,
--	  p_file in varchar2 default null ) is
--	--
--	  l_found boolean := false;
--	begin
--
--	  dbms_output.put_line( chr(10) );
--	  dbms_output.put_line( 'Debug info for ' ||
--									p_user );
--	  for c in ( select *
--					 from debugtab
--					 where userid = p_user
--					 and nvl( p_file, filename ) = filename )
--	  loop
--		 dbms_output.put_line( '---------------' ||
--									  rpad( '-', length( p_user ), '-' ) );
--		 l_found := true;
--		 dbms_output.put_line( 'USER:                 ' ||
--									  c.userid );
--		 dbms_output.put_line( 'MODULES:              ' ||
--									  c.modules );
--		 dbms_output.put_line( 'FILENAME:             ' ||
--									  c.filename );
--		 dbms_output.put_line( 'SHOW DATE:            ' ||
--									  c.show_date );
--		 dbms_output.put_line( 'DATE FORMAT:          ' ||
--									  c.date_format );
--		 dbms_output.put_line( 'NAME LENGTH:          ' ||
--									  c.name_length );
--		 dbms_output.put_line( 'SHOW SESSION ID:      ' ||
--									  c.session_id );
--		 dbms_output.put_line( ' ' );
--	  end loop;
--	 
--	  if not l_found then
--		 dbms_output.put_line( 'No debug setup.' );
--	  end if;
--
--	end status;

begin

	g_session_id := userenv('SESSIONID');
  
end UTL_TRACE;
/

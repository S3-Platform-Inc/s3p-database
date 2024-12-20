create sequence tasks.sessions_n_session_id_seq
    as integer;

alter sequence tasks.sessions_n_session_id_seq owner to sppadmin;

grant select, update on sequence tasks.sessions_n_session_id_seq to spptgbot;

create table nodes.node
(
    id     serial
        primary key,
    name   text not null,
    ip     text,
    config json
);

alter table nodes.node
    owner to sppadmin;

grant select, update on sequence nodes.node_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on nodes.node to spptgbot;

create table nodes.sessions
(
    id     serial
        primary key,
    start  timestamp with time zone not null,
    stop   timestamp with time zone,
    alive  timestamp with time zone,
    nodeid serial
        references nodes.node
);

alter table nodes.sessions
    owner to sppadmin;

grant select, update on sequence nodes.sessions_id_seq to spptgbot;

grant select, update on sequence nodes.sessions_nodeid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on nodes.sessions to spptgbot;

create table plugins.plugin
(
    id         serial
        primary key,
    repository text    not null,
    active     boolean not null,
    loaded     timestamp with time zone,
    config     json
);

alter table plugins.plugin
    owner to sppadmin;

grant select, update on sequence plugins.plugin_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on plugins.plugin to spptgbot;

create table tasks.status
(
    code integer not null
        primary key,
    name text    not null
        constraint status_pk
            unique
);

alter table tasks.status
    owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on tasks.status to spptgbot;

create table tasks.errors
(
    id       serial
        primary key,
    datetime timestamp with time zone not null,
    comment  text                     not null,
    taskid   serial
);

alter table tasks.errors
    owner to sppadmin;

grant select, update on sequence tasks.errors_id_seq to spptgbot;

grant select, update on sequence tasks.errors_taskid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on tasks.errors to spptgbot;

create table tasks.schedule
(
    id     serial
        primary key,
    start  timestamp with time zone not null,
    taskid serial
);

alter table tasks.schedule
    owner to sppadmin;

grant select, update on sequence tasks.schedule_id_seq to spptgbot;

grant select, update on sequence tasks.schedule_taskid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on tasks.schedule to spptgbot;

create table ml.model
(
    id     serial
        primary key,
    name   text,
    config json
);

alter table ml.model
    owner to sppadmin;

grant select, update on sequence ml.model_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on ml.model to spptgbot;

create table sources.source
(
    id      serial
        primary key,
    name    text not null
        constraint source_name_pk
            unique,
    sphere  text,
    created timestamp with time zone
);

alter table sources.source
    owner to sppadmin;

grant select, update on sequence sources.source_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on sources.source to spptgbot;

create table documents.document
(
    id          serial
        primary key,
    sourceid    serial
        references sources.source,
    title       text                     not null,
    weblink     text                     not null,
    published   timestamp with time zone not null,
    abstract    text,
    text        text,
    storagelink text,
    loaded      timestamp with time zone,
    otherdata   json
);

alter table documents.document
    owner to sppadmin;

grant select, update on sequence documents.document_id_seq to spptgbot;

grant select, update on sequence documents.document_sourceid_seq to spptgbot;

create index document_sourceid_index
    on documents.document (sourceid);

grant delete, insert, references, select, trigger, truncate, update on documents.document to spptgbot;

create table ml.plugin
(
    modelid serial
        references ml.model,
    primary key (id)
)
    inherits (plugins.plugin);

alter table ml.plugin
    owner to sppadmin;

grant select, update on sequence ml.plugin_modelid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on ml.plugin to spptgbot;

create table sources.plugin
(
    sourceid serial
        references sources.source,
    primary key (id)
)
    inherits (plugins.plugin);

alter table sources.plugin
    owner to sppadmin;

grant select, update on sequence sources.plugin_sourceid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on sources.plugin to spptgbot;

create table tasks.task
(
    id       serial
        primary key,
    status   integer not null
        references tasks.status,
    pluginid integer not null
        unique
);

alter table tasks.task
    owner to sppadmin;

grant select, update on sequence tasks.task_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on tasks.task to spptgbot;

create table tasks.sessions
(
    id           serial
        primary key,
    start        timestamp with time zone not null,
    stop         timestamp with time zone,
    taskid       serial
        constraint sessions_task_id_fk
            references tasks.task,
    n_session_id integer default nextval('tasks.sessions_n_session_id_seq'::regclass)
        references nodes.sessions
);

alter table tasks.sessions
    owner to sppadmin;

alter sequence tasks.sessions_n_session_id_seq owned by tasks.sessions.n_session_id;

grant select, update on sequence tasks.sessions_id_seq to spptgbot;

grant select, update on sequence tasks.sessions_taskid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on tasks.sessions to spptgbot;

create table ml.score
(
    id         serial
        primary key,
    score      json                     not null,
    date       timestamp with time zone not null,
    config     json,
    documentid serial
        references documents.document,
    pluginid   serial
        references ml.plugin
);

alter table ml.score
    owner to sppadmin;

grant select, update on sequence ml.score_id_seq to spptgbot;

grant select, update on sequence ml.score_documentid_seq to spptgbot;

grant select, update on sequence ml.score_pluginid_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on ml.score to spptgbot;

create table analytics.offload
(
    id     serial
        primary key,
    date   timestamp with time zone not null,
    params json
);

alter table analytics.offload
    owner to sppadmin;

grant select, update on sequence analytics.offload_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on analytics.offload to spptgbot;

create table analytics.offloaded_documents
(
    document integer not null
        primary key
        references documents.document,
    offload  integer
        references analytics.offload
);

alter table analytics.offloaded_documents
    owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on analytics.offloaded_documents to spptgbot;

create table users.role
(
    id   serial
        primary key,
    name text not null
);

alter table users.role
    owner to sppadmin;

grant select, update on sequence users.role_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on users.role to spptgbot;

create table users.role_source
(
    role   integer not null
        references users.role,
    source integer not null
        references sources.source,
    unique (role, source)
);

alter table users.role_source
    owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on users.role_source to spptgbot;

create table users."user"
(
    id        serial
        primary key,
    name      text not null,
    privilege json,
    auth      json
);

alter table users."user"
    owner to sppadmin;

grant select, update on sequence users.user_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on users."user" to spptgbot;

create table users.user_role
(
    user_id integer not null
        references users."user",
    role    integer not null
        references users.role,
    unique (user_id, role)
);

alter table users.user_role
    owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on users.user_role to spptgbot;

create table score.score
(
    id          serial
        primary key,
    score       json,
    comment     text,
    document_id integer
        references documents.document,
    user_id     integer
        references users."user",
    role_id     integer
        references users.role,
    date        timestamp with time zone,
    constraint score_pk
        unique (user_id, role_id, document_id)
);

alter table score.score
    owner to sppadmin;

grant select, update on sequence score.score_id_seq to spptgbot;

create index score_document_id_index
    on score.score using hash (document_id);

grant delete, insert, references, select, trigger, truncate, update on score.score to spptgbot;

create table analytics.digest
(
    id      serial
        constraint digest_pk
            primary key,
    date    timestamp with time zone not null,
    comment text
);

comment on table analytics.digest is 'for digests';

alter table analytics.digest
    owner to sppadmin;

grant select, update on sequence analytics.digest_id_seq to spptgbot;

grant delete, insert, references, select, trigger, truncate, update on analytics.digest to spptgbot;

create table analytics.digest_documents
(
    digest   integer not null,
    document integer not null,
    constraint digest_documents_pk
        unique (digest, document)
);

alter table analytics.digest_documents
    owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on analytics.digest_documents to spptgbot;

create materialized view control.experts_score_view as
SELECT sr.document_id,
       d.sourceid,
       d.title,
       d.weblink,
       d.published,
       d.abstract,
       d.loaded,
       d.otherdata,
       (SELECT s1.score ->> 'score'::text
        FROM score.score s1
        WHERE s1.user_id = 4
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_1_score,
       (SELECT s1.score ->> 'comment'::text
        FROM score.score s1
        WHERE s1.user_id = 4
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_1_comment,
       (SELECT s1.score ->> 'score'::text
        FROM score.score s1
        WHERE s1.user_id = 5
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_2_score,
       (SELECT s1.score ->> 'comment'::text
        FROM score.score s1
        WHERE s1.user_id = 5
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_2_comment,
       (SELECT s1.score ->> 'score'::text
        FROM score.score s1
        WHERE s1.user_id = 6
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_3_score,
       (SELECT s1.score ->> 'comment'::text
        FROM score.score s1
        WHERE s1.user_id = 6
          AND s1.document_id = sr.document_id
        LIMIT 1) AS user_3_comment
FROM score.score sr
         JOIN documents.document d ON sr.document_id = d.id
GROUP BY sr.document_id, d.id;

alter materialized view control.experts_score_view owner to sppadmin;

grant delete, insert, references, select, trigger, truncate, update on control.experts_score_view to spptgbot;

create view plugins.complete(tid, status, pid, repository, loaded, config, type, refid, refname) as
SELECT task.id AS tid,
       task.status,
       pl.id   AS pid,
       pl.repository,
       pl.loaded,
       pl.config,
       pl.type,
       pl.refid,
       pl.refname
FROM tasks.task
         JOIN (SELECT plugin.id,
                      plugin.repository,
                      plugin.loaded,
                      plugin.config,
                      'SOURCE'::text                      AS type,
                      plugin.sourceid                     AS refid,
                      (SELECT source.name
                       FROM sources.source
                       WHERE source.id = plugin.sourceid) AS refname
               FROM sources.plugin
               UNION ALL
               SELECT plugin.id,
                      plugin.repository,
                      plugin.loaded,
                      plugin.config,
                      'ML'::text                        AS type,
                      plugin.modelid                    AS refid,
                      (SELECT model.name
                       FROM ml.model
                       WHERE model.id = plugin.modelid) AS refname
               FROM ml.plugin) pl ON task.pluginid = pl.id;

comment on view plugins.complete is 'Выбирает задачи и добавляет к ним данные о плагине и связанным с ним объектом (источник, модель, pipeline)';

alter table plugins.complete
    owner to sppadmin;

grant insert, references, select, trigger, update on plugins.complete to spptgbot;

create view control.plugins_status
            (pl_id, pl_active, src_id, src_name, pl_rep, status_name, docs, percent, next_start) as
WITH plugin_data AS (SELECT pl.id    AS plid,
                            pl.active,
                            ss.id    AS ssid,
                            ss.name,
                            pl.repository,
                            pl.config,
                            st.name  AS status_name,
                            ts.start AS next_start
                     FROM tasks.task t
                              JOIN tasks.status st ON t.status = st.code
                              LEFT JOIN tasks.schedule ts ON t.id = ts.taskid
                              JOIN sources.plugin pl ON t.pluginid = pl.id
                              JOIN sources.source ss ON ss.id = pl.sourceid),
     document_counts AS (SELECT d.sourceid,
                                count(d.id)   AS doc_count,
                                count(sse.id) AS score_count
                         FROM documents.document d
                                  LEFT JOIN score.score sse ON sse.document_id = d.id
                         GROUP BY d.sourceid)
SELECT pls.plid                                                                                  AS pl_id,
       pls.active                                                                                AS pl_active,
       pls.ssid                                                                                  AS src_id,
       pls.name                                                                                  AS src_name,
       'https://github.com/'::text || pls.repository                                             AS pl_rep,
       pls.status_name,
       COALESCE(dc.doc_count, 0::bigint)                                                         AS docs,
       COALESCE(dc.score_count::numeric / NULLIF(dc.doc_count::numeric, 0::numeric), 0::numeric) AS percent,
       pls.next_start
FROM plugin_data pls
         LEFT JOIN document_counts dc ON pls.ssid = dc.sourceid;

alter table control.plugins_status
    owner to sppadmin;

create function nodes.active_sessions()
    returns TABLE(session_id integer, node_id integer, alive timestamp with time zone)
    language plpgsql
as
$$
begin
    RETURN QUERY SELECT ns.id, ns.nodeid, ns.alive as alive
                 FROM nodes.sessions ns
                 WHERE (ns.alive is NOT NULL AND ns.stop IS NULL AND ns.start < NOW());
end;
$$;

comment on function nodes.active_sessions() is 'Возвращает таблицу со всеми активными сессиями всех узлов';

alter function nodes.active_sessions() owner to sppadmin;

grant execute on function nodes.active_sessions() to spptgbot;

create function nodes.active_session(nodeid integer) returns integer
    language plpgsql
as
$$
    declare sid integer;
begin

    select session_id into sid from nodes.active_sessions() where node_id = nodeid ORDER BY alive DESC LIMIT 1;
    RETURN sid;
end;
$$;

comment on function nodes.active_session(integer) is 'Возвращает id активной сессии узла по его id (передаваемый параметр)';

alter function nodes.active_session(integer) owner to sppadmin;

grant execute on function nodes.active_session(integer) to spptgbot;

create function nodes.alive(__id integer) returns integer
    language plpgsql
as
$$
    declare
        sid integer;
begin
    select nodes.active_session(__id) into sid;
    if (sid IS NULL)
    THEN
        insert into nodes.sessions(start, nodeid, alive)
        VALUES (now(), __id, now());
    end if;

    UPDATE nodes.sessions SET alive = now() WHERE id = sid;

    return sid;
end;
$$;

comment on function nodes.alive(integer) is 'Функция, которую вызывает узел SPP для обновления статуса "я жив"';

alter function nodes.alive(integer) owner to sppadmin;

grant execute on function nodes.alive(integer) to spptgbot;

create function nodes.observe_node_session() returns integer
    language plpgsql
as
$$
    declare
        dead_sessions integer;
begin

    SELECT COUNT(*) into dead_sessions FROM nodes.active_sessions() n, LATERAL nodes.kill_session(n.session_id) sid WHERE AGE(now(), alive) > '3 secs'::interval;

--     SELECT sid FROM nodes.active_sessions() n, LATERAL nodes.kill_session(n.session_id) sid WHERE AGE(now(), alive) > interval '3 secs';

    return dead_sessions;
end;
$$;

comment on function nodes.observe_node_session() is 'Просматривает все активные сессии и проверяет, чтобы дата последнего обновления статуса "я жив" узла SPP был не больше N секунд. Если находятся сессии, чей статус не обновился, то для этой сессии вызывается функция nodes.kill_session(id integer)';

alter function nodes.observe_node_session() owner to sppadmin;

grant execute on function nodes.observe_node_session() to spptgbot;

create function nodes.kill_session(__id integer) returns integer
    language plpgsql
as
$$
begin
    UPDATE nodes.sessions SET alive = NULL, stop = now() WHERE id = __id;
    return __id;
end;
$$;

comment on function nodes.kill_session(integer) is 'Фукнция для уничтожения активной сессии узла SPP';

alter function nodes.kill_session(integer) owner to sppadmin;

grant execute on function nodes.kill_session(integer) to spptgbot;

create function tasks.add_task(__pluginid integer, iscreateschedule boolean) returns integer
    language plpgsql
as
$$
    declare
        tid integer;
begin
    INSERT INTO tasks.task (status, pluginid) values (0, __pluginID) RETURNING id into tid;

    IF isCreateSchedule is true THEN
        perform tasks.schedule(tid, null);
    end if;

    return tid;
end
$$;

alter function tasks.add_task(integer, boolean) owner to sppadmin;

grant execute on function tasks.add_task(integer, boolean) to spptgbot;

create function plugins.on_addition_plugin() returns trigger
    language plpgsql
as
$$
begin

    if not EXISTS(select *
                  FROM tasks.task t
                  WHERE t.pluginid = new.id)
    THEN
--         Добавлен плагин, задача для которого не была создана
        perform tasks.add_task(new.id, new.active);
    end if;

--     perform public.observe_plugins();

    return new;
end
$$;

alter function plugins.on_addition_plugin() owner to sppadmin;

create trigger plugin_insert_observer
    after insert
    on plugins.plugin
execute procedure plugins.on_addition_plugin();

create trigger ml_plugin_insert_observer
    after insert
    on ml.plugin
    for each row
execute procedure plugins.on_addition_plugin();

create trigger s_plugin_insert_observer
    after insert
    on sources.plugin
    for each row
execute procedure plugins.on_addition_plugin();

grant execute on function plugins.on_addition_plugin() to spptgbot;

create function plugins.plugin_update_active() returns trigger
    language plpgsql
as
$$
    declare tid integer;
begin

    select id into tid from tasks.task where pluginid = new."id";

    if (new.active is true) then
        perform tasks.schedule(tid, now());
    else
        perform * from tasks.schedule sch, lateral tasks.unschedule(sch.id, 80) where sch.taskid = tid;
    end if;

    return new;
end
$$;

alter function plugins.plugin_update_active() owner to sppadmin;

create trigger plugin_update_observer
    after update
        of active
    on plugins.plugin
    for each row
execute procedure plugins.plugin_update_active();

create trigger s_plugin_update_observer
    after update
        of active
    on ml.plugin
    for each row
execute procedure plugins.plugin_update_active();

create trigger s_plugin_update_observer
    after update
        of active
    on sources.plugin
    for each row
execute procedure plugins.plugin_update_active();

grant execute on function plugins.plugin_update_active() to spptgbot;

create function tasks.schedule(taskid integer, start timestamp with time zone) returns integer
    language plpgsql
as
$$
    declare schID integer;
begin

    if (start is null) then
--         Если время запуска не указана, то выбрать текущее время
        start := now();
    end if;
    if (start < now()) then
        raise exception 'Start time --> % in the past', start;
    end if;

    insert into tasks.schedule (start, taskid) values (start, schedule.taskID) returning schedule.id into schID;
    UPDATE tasks.task t set status = 10 where t.id = taskID;

    return schID;
end
$$;

alter function tasks.schedule(integer, timestamp with time zone) owner to sppadmin;

grant execute on function tasks.schedule(integer, timestamp with time zone) to spptgbot;

create function tasks.unschedule(scheduleid integer, _status integer) returns integer
    language plpgsql
as
$$
begin

    if (_status is not null) then
--         Изменение статуса при необходимости
        perform tasks.set_status((select taskid from tasks.schedule where id = scheduleID), _status);
    end if;

--     Удаление записи из таблицы расписания
    delete from tasks.schedule where id = scheduleID;

    return scheduleID;
end
$$;

alter function tasks.unschedule(integer, integer) owner to sppadmin;

grant execute on function tasks.unschedule(integer, integer) to spptgbot;

create function tasks.set_status(taskid integer, _status integer) returns integer
    language plpgsql
as
$$
begin

    UPDATE tasks.task set status = _status where id = taskID;
    return taskID;
end
$$;

alter function tasks.set_status(integer, integer, text) owner to sppadmin;

grant execute on function tasks.set_status(integer, integer, text) to spptgbot;

create function nodes.plugin_types(nodeid integer)
    returns TABLE(type text)
    language plpgsql
as
$$
begin
    return query select value as type from json_array_elements_text((select config -> 'plugins' -> 'types' from nodes.node where id = nodeID));
end
$$;

alter function nodes.plugin_types(integer) owner to sppadmin;

grant execute on function nodes.plugin_types(integer) to spptgbot;

create function nodes.init(__name text, __ip text, __config json) returns integer
    language plpgsql
as
$$
    declare
        __id integer;
begin
    if not EXISTS(select *
                  FROM nodes.node
                  WHERE name = __name)
    THEN

        insert into nodes.node (name, ip, config)
        VALUES (__name, __ip, __config);

        RETURN currval('nodes.node_id_seq');
    else
        select id into __id
                  FROM nodes.node
                  WHERE name = __name;
        return __id;
    end if;
end;
$$;

alter function nodes.init(text, text, json) owner to sppadmin;

grant execute on function nodes.init(text, text, json) to spptgbot;

create function tasks.broke(nodeid integer, sessionid integer, comment text) returns integer
    language plpgsql
as
$$
    declare _tid integer;
begin
    UPDATE tasks.sessions set stop = now() where id = broke.sessionID;
    UPDATE tasks.task set status = 60 where id = (select taskid from tasks.sessions where id = broke.sessionID) returning id into _tid;

    insert into tasks.errors (datetime, comment, taskid) values (now(), broke.comment, _tid);
    return _tid;
end
$$;

alter function tasks.broke(integer, integer, text) owner to sppadmin;

grant execute on function tasks.broke(integer, integer, text) to spptgbot;

create function plugins.timer(id integer) returns interval
    language plpgsql
as
$$
    declare int interval;
begin
    select (config -> 'task' -> 'trigger' ->> 'interval')::interval into int from plugins.plugin where plugin.id = timer.id limit 1;
    return int;
end
$$;

alter function plugins.timer(integer) owner to sppadmin;

grant execute on function plugins.timer(integer) to spptgbot;

create function tasks.finish(nodeid integer, sessionid integer) returns integer
    language plpgsql
as
$$
    declare _tid integer; _pid integer;
begin
    UPDATE tasks.sessions set stop = now() where id = finish.sessionID; -- // Завершение текущей сессии
    UPDATE tasks.task set status = 50
                      where id = (select taskid from tasks.sessions where id = finish.sessionID)
                      returning id into _tid; -- // Обновление статуса задача на 'finished'
    select pc.pid into _pid from plugins.complete pc where pc.tid = _tid;

    if (select * from plugins.timer(_pid)) is not null then
        perform tasks.schedule(_tid, now() + (select * from plugins.timer(_pid))); -- // Добавление нового расписания
    end if;

    return _tid;

end
$$;

alter function tasks.finish(integer, integer) owner to sppadmin;

grant execute on function tasks.finish(integer, integer) to spptgbot;

create function tasks.relevant(nodeid integer)
    returns TABLE(sessionid integer, taskid integer, taskstatus integer, pluginid integer, repository text, loaded timestamp with time zone, config json, type text, referenceid integer, referencename text)
    language plpgsql
as
$$
    declare
        _tid integer; _schid integer; _tsession integer; _pluginId integer;
begin
--         Эта функция должна выбрать одну задачу, основываясь на таблице расписания. Удалить выбранную запись расписания, собрать данные о задаче и об плагине этой задачи и вернуть их в форме таблицы.
    LOCK TABLE tasks.schedule;

--     Выбираются такие задачи, для которых плагин имеет тип, который поддерживает узел. При этом на полученные задачи должно иметься расписание. Затем выбирается одна старая запланированная задача.
    select sch.id, pl.tid, pl.pid into _schid, _tid, _pluginId from plugins.complete pl
        left join tasks.schedule sch on sch.taskid = pl.tid
             where
                 pl.type in (select * from nodes.plugin_types(nodeID))
                 and sch.id is not null
                 and sch.start < now()
             order by sch.start
             limit 1;

--     select schedule.id, schedule.taskid into schid, tid from tasks.schedule where tasks.schedule.start < now() order by schedule.start limit 1;
    if (_schid is null) then
--         Если не было получена запись расписания, значит нет задач для запуска
        return;
    end if;

    perform tasks.set_status(_tid, 20); -- // Задача перешла в режим "получена" (<given> status)
    perform tasks.unschedule(_schid, null); -- // удаление записи расписания

    insert into tasks.sessions (start, stop, taskid, n_session_id)
        values (
                now(),
                null,
                _tid,
                null
        )
        returning id into _tsession; -- // Создание сессии задачи и получение id новой сессии
    return query select _tsession as sessionid, * from plugins.complete where complete.tid = _tid; -- // полные данные о задаче с ID сессии этой задачи
end
$$;

alter function tasks.relevant(integer) owner to sppadmin;

grant execute on function tasks.relevant(integer) to spptgbot;

create function documents.equals(lhid integer, lhtitle text, lhweblink text, lhpubdate timestamp with time zone, lhsource integer, rhid integer, rhtitle text, rhweblink text, rhpubdate timestamp with time zone, rhsource integer) returns boolean
    language plpgsql
as
$$

begin

    --     1. Сначала проверяем совпадают ли у документов источники
--     Если источники документов не равны, то ДОКУМЕНТЫ НЕ РАВНЫ
    IF (lhSource <> rhSource) THEN
        RETURN FALSE;
    end if;

--      2. Проверяем есть ли у документов поле ID. Если у какого-нибудь документа поля ID нет, то проверять соответствие будем по 3 уникальным полям, который должны быть.
    IF (lhID IS NULL) OR (rhID IS NULL) THEN
        RETURN (lhTitle = rhTitle) AND (lhWebLink = rhWebLink) AND (lhPubDate = rhPubDate);
    end if;

--      3. Если у двух документов есть ID, то сравнение происходит по ним
    IF (lhID IS NOT NULL) AND (rhID IS NOT NULL) THEN
        RETURN lhID = rhID;
    end if;

    RETURN FALSE;
end;
$$;

alter function documents.equals(integer, text, text, timestamp with time zone, integer, integer, text, text, timestamp with time zone, integer) owner to sppadmin;

grant execute on function documents.equals(integer, text, text, timestamp with time zone, integer, integer, text, text, timestamp with time zone, integer) to spptgbot;

create function documents.save(sourceid integer, newtitle text, newabstract text, newtext text, newweblink text, newlocallink text, newotherdata json, newpubdate timestamp with time zone, newloaddate timestamp with time zone) returns integer
    language plpgsql
as
$$
declare
    docID INTEGER;

begin

    select id into docID FROM documents.document d
             WHERE d.sourceid = save.sourceID
               AND d.title = save.newTitle
               AND d.weblink = save.newWeblink
               AND d.published = save.newPubDate;

    if (docID is null) then
        insert into documents.document (sourceid, title, weblink, published, abstract, text, storagelink, loaded, otherdata)
        VALUES (save.sourceID, newTitle, newWeblink, newPubDate, newAbstract, newText, newLocalLink, newLoadDate, newOtherData) returning id into docID;
    else
        update documents.document d set
                                      abstract = newAbstract,
                                      text = newText,
                                      storagelink = newLocalLink,
                                      loaded = newLoadDate,
                                      otherdata = newOtherData
        where d.id = docID;

    end if;

    return docID;
end;
$$;

alter function documents.save(integer, text, text, text, text, text, json, timestamp with time zone, timestamp with time zone) owner to sppadmin;

grant execute on function documents.save(integer, text, text, text, text, text, json, timestamp with time zone, timestamp with time zone) to spptgbot;

create function documents."all"(_sourceid integer)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone, abstract text, text text, storagelink text, loaded timestamp with time zone, otherdata json)
    language plpgsql
as
$$
begin
--     Фукнция для получения всех документов.
--          Если источник указан, то выбираются все документы этого источника
--          Если источник не указан, то выдаются все документы
    return query select * from documents.document d
                          where (_sourceID is NULL) or (_sourceID = d.sourceid);
end
$$;

alter function documents."all"(integer) owner to sppadmin;

grant execute on function documents."all"(integer) to spptgbot;

create function documents.littles(_sourceid integer)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone)
    language plpgsql
as
$$
begin
--     Функция возвращает все документы (как в функции documents."all"), но обрезает, чтобы уменьшить размер получаемого пакета
--          такая функция используется там, где нужно сравнить документы (например, в модуле фильтрации платформы)
    return query select "all".id, "all".sourceid, "all".title, "all".weblink, "all".published from documents.all(_sourceid);
end
$$;

alter function documents.littles(integer) owner to sppadmin;

grant execute on function documents.littles(integer) to spptgbot;

create function analytics.offload_document(offloadid integer, documentid integer) returns integer
    language plpgsql
as
$$
    declare __id integer;
begin
--         Добавление новой выгрузки
    insert into analytics.offloaded_documents (document, offload) VALUES (documentID, offloadID) returning document into __id;
    return 1;
end
$$;

alter function analytics.offload_document(integer, integer) owner to sppadmin;

grant execute on function analytics.offload_document(integer, integer) to spptgbot;

create function analytics.export(export_id integer)
    returns TABLE(id integer, title text, weblink text, published timestamp with time zone, abstract text, text text, storagelink text, loaded timestamp with time zone, otherdata json, source_id integer, source_name text)
    language plpgsql
as
$$
    declare offid integer;
begin
--         Добавление новой выгрузки
    if (export_id is NULL) then
        if exists(select * from documents.document d where d.id not in (select document from analytics.offloaded_documents)) then
            insert into analytics.offload (date) VALUES (now()) returning offload.id into offid;
            return query select d.id, d.title, d.weblink, d.published, d.abstract, d.text, d.storagelink, d.loaded, d.otherdata, s.id, s.name
                     from documents.document d join sources.source s on d.sourceid = s.id,
                         lateral analytics.offload_document(offid, d.id)
                     where d.id not in (select document from analytics.offloaded_documents);
        end if;
    else
        return query select d.id, d.title, d.weblink, d.published, d.abstract, d.text, d.storagelink, d.loaded, d.otherdata, s.id, s.name
                         from analytics.offloaded_documents offdoc left join documents.document d on offdoc.document = d.id join sources.source s on s.id = d.sourceid
                         where offdoc.offload = export_id;
    end if;
end
$$;

alter function analytics.export(integer) owner to sppadmin;

grant execute on function analytics.export(integer) to spptgbot;

create function analytics.export_lists()
    returns TABLE(id integer, date timestamp with time zone, count bigint)
    language plpgsql
as
$$
begin
    return query select o.id, o.date, count(*) from analytics.offload o left join analytics.offloaded_documents od on o.id = od.offload
                 group by o.id order by o.id;
end
$$;

alter function analytics.export_lists() owner to sppadmin;

grant execute on function analytics.export_lists() to spptgbot;

create function control.plugins_observe()
    returns TABLE(id integer, name text, repository text, active boolean, status_code integer, status text, docs bigint, errors bigint)
    language plpgsql
as
$$
begin
    return query select sp.id as id,s.name, sp.repository, sp.active, ts.code as status_code, ts.name as status, count(d.id) as docs, count(te.id) as errors
        from (((sources.plugin sp join sources.source s on sp.sourceid = s.id)
            join tasks.task t on sp.id = t.pluginid)
            left join tasks.status ts on ts.code = t.status
            left join tasks.errors te on te.taskid = t.id)
            left join documents.document d on d.sourceid = sp.sourceid
        group by sp.id, s.id, t.id, ts.code order by sp.id;
end
$$;

alter function control.plugins_observe() owner to sppadmin;

grant execute on function control.plugins_observe() to spptgbot;

create function users.roleinfo(_id integer)
    returns TABLE(id integer, name text, src_id integer, src_name text, src_sphere text)
    language plpgsql
as
$$
begin
    return query select r.id, r.name, s.id, s.name, s.sphere
                 from users.role r join users.role_source rs on r.id = rs.role
                     join sources.source s on rs.source = s.id
                 where r.id = _id;
end
$$;

alter function users.roleinfo(integer) owner to sppadmin;

grant execute on function users.roleinfo(integer) to spptgbot;

create function score.save(_uid integer, telegram_id integer, _did integer, _rid integer, _score json, _comment text) returns integer
    language plpgsql
as
$$
    declare sid integer;
begin

    insert into score.score (score, comment, document_id, user_id, role_id, date)
        values (_score, _comment, _did, _uid, _rid, now()) returning id into sid;
    return sid;
end
$$;

alter function score.save(integer, integer, integer, integer, json, text) owner to sppadmin;

grant execute on function score.save(integer, integer, integer, integer, json, text) to spptgbot;

create function users.sources(_id integer) returns integer[]
    language plpgsql
as
$$
    declare srcs integer[];
begin
--         Array всех источников, доступных для пользователя (user ID)
    select ARRAY(
    select distinct rs.source
    from (users.user u join users.user_role ur on u.id = ur.user_id)
        join users.role_source rs on ur.role = rs.role
    where u.id = _id
    order by rs.source
       ) into srcs;
    return srcs;
end
$$;

alter function users.sources(integer) owner to sppadmin;

grant execute on function users.sources(integer) to spptgbot;

create function score.documents(_uid integer)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone, abstract text, text text, storagelink text, loaded timestamp with time zone, otherdata json)
    language plpgsql
as
$$
begin
-- Таблица всех документов, доступных для оценки пользователя (user ID)
--     return query select * from documents.document dd
--     where dd.id in
--         (select md.id from documents.document md
--             except
--             select d.id
--             from documents.document d
--                 join score.score s on d.id = s.document_id
--             where s.user_id = _uid
--             )
--         and
--         dd.sourceid = ANY(users.sources(_uid));

    return query select d.id, d.sourceid, d.title, d.weblink, d.published, d.abstract, d.text, d.storagelink, d.loaded, d.otherdata
                 from (select od.id, od.sourceid, od.title, od.weblink, od.published, od.abstract, od.text, od.storagelink, od.loaded, od.otherdata
                        from documents.document od
                        where od.published >= date '2024.04.01' and
                            od.sourceid = ANY(users.sources(_uid))) d
                    left join score.score s on s.document_id = d.id
                where s.id is null;
end
$$;

alter function score.documents(integer, integer) owner to sppadmin;

grant execute on function score.documents(integer, integer) to spptgbot;

create function score.stats(_uid integer)
    returns TABLE(srcid integer, srcname text, documents bigint)
    language plpgsql
as
$$
begin
--     Возвращает количество документов для каждого источника, которые были оценены пользователем (user ID)
    return query select src.id, src.name, count(d.id)
        from documents.document d
            left join sources.source src on d.sourceid = src.id
            join score.score s on d.id = s.document_id
        where s.user_id = _uid
        group by src.id;
end
$$;

alter function score.stats(integer) owner to sppadmin;

grant execute on function score.stats(integer) to spptgbot;

create function score.document(_uid integer, srcid integer)
    returns TABLE(id integer, title text, weblink text, published timestamp with time zone, abstract text, storagelink text, loaded timestamp with time zone, otherdata json, src_id integer, src_name text, src_sphere text)
    language plpgsql
as
$$
begin
    return query
        select od.id, od.title, od.weblink, od.published, od.abstract, od.storagelink, od.loaded, od.otherdata, src.id, src.name, src.sphere
        from (select d.* from score.documents(_uid) d
        where ((srcid is null) or ((srcid is not null) and (d.sourceid = srcid)))
        order by d.id
        limit 1) od
        join sources.source src on od.sourceid = src.id;

--     return query select od.id, od.title, od.weblink, od.published, od.abstract, od.storagelink, od.loaded, od.otherdata, src.id, src.name, src.sphere
--                  from (select d.*
--                        from documents.document d
--                        where ((srcid is null) or ((srcid is not null) and (d.sourceid = srcid)))
--                          and (d.id not in (select id from score.score s where s.user_id = _uid))
--                          and d.sourceid = ANY(users.sources(_uid))
--                        order by d.id
--                        limit 1) od
--                  join sources.source src on src.id = od.sourceid;
end
$$;

alter function score.document(integer, integer) owner to sppadmin;

grant execute on function score.document(integer, integer) to spptgbot;

create function score.roles(_uid integer)
    returns TABLE(id integer, name text)
    language plpgsql
as
$$
begin
    return query
        select r.id, r.name
        from users.role r
        where r.id = ANY(users.roles(_uid));
end
$$;

alter function score.roles(integer) owner to sppadmin;

grant execute on function score.roles(integer) to spptgbot;

create function users.roles(_uid integer, _sid integer)
    returns TABLE(id integer, name text)
    language plpgsql
as
$$
    declare roles integer[];
begin
--         Array всех ролей, доступных для источника (source ID) для пользователя (user ID)
    return query select distinct r.id, r.name
    from users.role_source rs join users.role r on rs.role = r.id
    where rs.role = ANY(users.roles(_uid)) and rs.source = _sid;
end
$$;

alter function users.roles(integer, integer) owner to sppadmin;

grant execute on function users.roles(integer, integer) to spptgbot;

create function sources."create"(_name text, _sphere text, _roles integer[]) returns integer
    language plpgsql
as
$$
    declare sid integer; _role integer;
begin
    insert into sources.source (name, sphere, created)
        values (_name, _sphere, now()) returning id into sid;

    foreach _role in array _roles loop
        insert into users.role_source (role, source) VALUES (_role, sid);
    end loop;
    return sid;
end
$$;

alter function sources."create"(text, text, integer[]) owner to sppadmin;

grant execute on function sources."create"(text, text, integer[]) to spptgbot;

create function users.auth(_id bigint, _token text)
    returns TABLE(id integer, name text, privilege json, role_id integer, role_name text)
    language plpgsql
as
$$
    declare uid integer;
begin
    select u.id into uid from users.user u where (u.auth#>>'{telegram}')::bigint = _id;

    if uid is not null
    THEN
        return query select u.id, u.name, u.privilege, r.id, r.name
                     from users.user u join users.user_role ur on u.id = ur.user_id
                         join users.role r on ur.role = r.id
                     where u.id = uid;
    end if;
end
$$;

alter function users.auth(bigint, text) owner to sppadmin;

grant execute on function users.auth(bigint, text) to spptgbot;

create function analytics.digests()
    returns TABLE(id integer, date timestamp with time zone, comment text)
    language plpgsql
as
$$
begin
    return query select *
                 from analytics.digest;
end
$$;

alter function analytics.digests() owner to sppadmin;

grant execute on function analytics.digests() to spptgbot;

create function analytics.selection(_role integer)
    returns TABLE(document integer, sids integer[], users integer[], scores json[])
    language plpgsql
as
$$
begin
    return query select ss.document_id, array_agg(ss.id), array_agg(ss.user_id), array_agg(ss.score)
                 from score.score ss
                     join (select distinct s.document_id
                     from score.score s join users."user" u on u.id = s.user_id
                        left join analytics.digest_documents dd on dd.document = s.document_id
                     where dd.digest is null) sdd on ss.document_id = sdd.document_id
                where ss.role_id = _role
                group by ss.document_id;
end
$$;

alter function analytics.selection(integer) owner to sppadmin;

grant execute on function analytics.selection(integer) to spptgbot;

create function documents.without_text(_did integer)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone, abstract text, storagelink text, loaded timestamp with time zone, otherdata json)
    language plpgsql
as
$$
begin
    return query select d.id, d.sourceid, d.title, d.weblink, d.published, d.abstract, d.storagelink, d.loaded, d.otherdata
                 from documents.document d
                 where d.id = _did
                 limit 1;
end
$$;

alter function documents.without_text(integer) owner to sppadmin;

grant execute on function documents.without_text(integer) to spptgbot;

create function documents.last(_sourcename text)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone)
    language plpgsql
as
$$
    declare _sid integer;
begin
--     Функция возвращает последний документ (как в функции documents."all"), но обрезает, чтобы уменьшить размер получаемого пакета
--          такая функция используется там, где нужно сравнить документы (например, в модуле фильтрации платформы)

    select id into _sid from sources.source where name = _sourcename;
    return query select d.id, d.sourceid, d.title, d.weblink, d.published
                 from documents.document d
                 where d.sourceid = _sid
                 order by d.published desc
                 limit 1;
end
$$;

alter function documents.last(text) owner to sppadmin;

grant execute on function documents.last(text) to spptgbot;

create function documents.last(_sourceid integer)
    returns TABLE(id integer, sourceid integer, title text, weblink text, published timestamp with time zone)
    language plpgsql
as
$$
begin
--     Функция возвращает все документы (как в функции documents."all"), но обрезает, чтобы уменьшить размер получаемого пакета
--          такая функция используется там, где нужно сравнить документы (например, в модуле фильтрации платформы)
    return query select d.id, d.sourceid, d.title, d.weblink, d.published
                 from documents.document d
                 where d.sourceid = _sourceid
                 order by d.published desc
                 limit 1;
end
$$;

alter function documents.last(integer) owner to sppadmin;

grant execute on function documents.last(integer) to spptgbot;

create function score.info_for(_uid integer)
    returns TABLE(srcid integer, srcname text)
    language plpgsql
as
$$
begin
--     Возвращает количество документов для каждого источника, которые еще не оценивались пользователем (user ID)
    return query select src.id, src.name
        from score.documents(_uid) d
            left join sources.source src on d.sourceid = src.id
    group by src.id, src.name;
end
$$;

alter function score.info_for(integer) owner to sppadmin;

grant execute on function score.info_for(integer) to spptgbot;

create function users.roles(_id integer) returns integer[]
    language plpgsql
as
$$
    declare roles integer[];
begin
--         Array всех ролей, доступных для пользователя (user ID)
    select ARRAY(
    select distinct ur.role
    from (users.user u join users.user_role ur on u.id = ur.user_id)
    where u.id = _id
    order by ur.role
       ) into roles;
    return roles;
end
$$;

alter function users.roles(integer) owner to sppadmin;

create function tasks.check_add_task() returns trigger
    language plpgsql
as
$$
    declare pluginIdExists boolean;
begin
    select (pl.id is not null) from plugins.plugin pl where pl.id = new.pluginid into pluginIdExists;
    if (pluginIdExists) then
        return NEW;
    else
        raise exception 'Nonexistent ID --> %', new.pluginid;
        return null;
    end if;
end
$$;

alter function tasks.check_add_task() owner to sppadmin;

create trigger pluginid_add_task_check
    before insert or update
    on tasks.task
    for each row
execute procedure tasks.check_add_task();

create function tasks.stop(_taskid integer) returns integer
    language plpgsql
as
$$
begin
    if exists(select * from tasks.schedule s where s.taskid = _taskid) then
        --     Удаление записи из таблицы расписания
        delete from tasks.schedule where taskid = _taskid;
    end if;
    select tasks.set_status(_taskid, 0);

    return 1;
end
$$;

alter function tasks.stop(integer) owner to sppadmin;

create function plugins.update_trigger_interval(p_id integer, p_new_interval text) returns void
    language plpgsql
as
$$
BEGIN
    UPDATE plugins.plugin
    SET config = jsonb_set(
        config::jsonb,
        '{task,trigger,interval}',
        p_new_interval,
        false
    )::json
    WHERE id = p_id;
END;
$$;

alter function plugins.update_trigger_interval(integer, text) owner to sppadmin;

create function documents.exists(_sourceid integer, _title text, _weblink text, _published timestamp with time zone) returns boolean
    language plpgsql
as
$$
begin
--     Функция находит документ в таблице documents.document по сложному идентификатору (title, weblink, published)
--     Возвращает значение TRUE или FALSE
    return exists(SELECT *
FROM
    documents.littles(_sourceid) d
WHERE
    d.title = _title
    AND
    d.weblink = _weblink
    AND
    d.published = _published);
end
$$;

alter function documents.exists(integer, text, text, timestamp with time zone) owner to sppadmin;

create function sources.add_plugin(_src_id integer, _repository text, _active boolean, _config json) returns integer
    language plpgsql
as
$$
    declare _pl_id integer;
begin
    insert into sources.plugin (repository, active, loaded, config, sourceid)
        values (_repository, _active, now(), _config, _src_id) returning id into _pl_id;

    return _pl_id;
end
$$;

alter function sources.add_plugin(integer, text, boolean, json) owner to sppadmin;

create function documents.save_if_exist(_sourceid integer, newtitle text, newabstract text, newtext text, newweblink text, newlocallink text, newotherdata json, newpubdate timestamp with time zone, newloaddate timestamp with time zone) returns integer
    language plpgsql
as
$$
declare
    docID INTEGER;
    _is_exists BOOLEAN;
begin
    select documents.exists(_sourceid, newtitle, newweblink, newpubdate) into _is_exists;

    if (docID is null) then
        insert into documents.document (sourceid, title, weblink, published, abstract, text, storagelink, loaded, otherdata)
        VALUES (_sourceid, newTitle, newWeblink, newPubDate, newAbstract, newText, newLocalLink, newLoadDate, newOtherData) returning id into docID;
        return docID;
    end if;

    return -1;
end;
$$;

alter function documents.save_if_exist(integer, text, text, text, text, text, json, timestamp with time zone, timestamp with time zone) owner to sppadmin;


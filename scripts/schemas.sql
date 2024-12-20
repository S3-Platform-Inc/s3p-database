create schema nodes;

comment on schema nodes is 'Схема для представления и работы с функциями';

alter schema nodes owner to sppadmin;

grant create, usage on schema nodes to spptgbot;

create schema tasks;

comment on schema tasks is 'Схема для представления и работы с задачами';

alter schema tasks owner to sppadmin;

grant create, usage on schema tasks to spptgbot;

create schema plugins;

comment on schema plugins is 'Схема для представления и работы с плагинами';

alter schema plugins owner to sppadmin;

grant create, usage on schema plugins to spptgbot;

create schema sources;

comment on schema sources is 'схема для представления и работы с источниками';

alter schema sources owner to sppadmin;

grant create, usage on schema sources to spptgbot;

create schema ml;

comment on schema ml is 'Схема для представления и работы с ml';

alter schema ml owner to sppadmin;

grant create, usage on schema ml to spptgbot;

create schema documents;

comment on schema documents is 'Схема для представления и работы с документами';

alter schema documents owner to sppadmin;

grant create, usage on schema documents to spptgbot;

create schema analytics;

alter schema analytics owner to sppadmin;

grant create, usage on schema analytics to spptgbot;

create schema control;

alter schema control owner to sppadmin;

grant create, usage on schema control to spptgbot;

create schema score;

comment on schema score is 'schema for scoring process';

alter schema score owner to sppadmin;

grant create, usage on schema score to spptgbot;

create schema users;

alter schema users owner to sppadmin;

grant create, usage on schema users to spptgbot;


drop database if exists lab2;
create database lab2;
use lab2;

create table course(
	cno char(8) primary key,
    cname varchar(100) not null
);
create table major(
	mno char(8) primary key,
    mname varchar(100) not null
);
create table student(
	sno char(8) primary key,
    sname varchar(100) not null,
    sex char(20) not null,
    smno char(8) not null,
    syear int not null,
    sgrade int not null default 0,
    sphone char(11),
    sphoto blob,
    foreign key (smno) references major(mno)
);
create table major_change(
	csno char(8),
    cmno_from char(8),
    cmno_to char(8),
    cyear int,
    primary key (csno, cmno_from, cmno_to, cyear),
    foreign key (csno) references student(sno),
    foreign key (cmno_from) references major(mno),
    foreign key (cmno_to) references major(mno)
);
create table grade(
	gsno char(8),
    gcno char(8),
    score int not null,
    primary key (gsno, gcno),
    foreign key (gsno) references student(sno),
    foreign key (gcno) references course(cno)
);
create table award_punish(
	aid int auto_increment primary key,
	asno char(8),
    atime date,
    acontent varchar(100) not null,
    foreign key (asno) references student(sno)
);

delimiter //
create trigger before_major_change_insert
before insert on major_change
for each row
begin
	declare student_syear int;
    declare origin_major char(8);
    declare student_major_changes int;
    
    select syear into student_syear from student where sno = new.csno;
    if new.cyear < student_syear then
		signal sqlstate '45000'
			set message_text = 'major change must be later than the time of admission';
	end if;
    
    select smno into origin_major from student where sno = new.csno;
    if origin_major = new.cmno_to then
		signal sqlstate '45000'
			set message_text = 'origin major must be different from target major';
	end if;
    
    select count(*) into student_major_changes from major_change where csno = new.csno and cyear = new.cyear;
    if student_major_changes >= 1 then
		signal sqlstate '45000'
			set message_text = 'this student has changed major once this year';
	end if;
end;
//
delimiter ;

delimiter //
create procedure change_major(
	in psno char(8),
    in pmno_to char(8),
    in pyear int
)
begin
	declare exit handler for sqlexception
    begin
		rollback;
        resignal;
	end;
    
    start transaction;
    insert into major_change values (psno, (select smno from student where sno = psno), pmno_to, pyear);
    update student set smno = pmno_to where sno = psno;
    commit;
end;
//
delimiter ;

delimiter //
create procedure insert_award_punish(
	psno char(8),
    pcontent varchar(100)
)
begin
	declare student_name varchar(100);
    declare cur_time date;
	
    select sname into student_name from student where sno = psno;
    set cur_time = curdate();
    
    insert into award_punish (asno, atime, acontent) values (psno, cur_time, pcontent);
end;
//
delimiter ;



delimiter //
create function cal_ave_score(
	fsno char(8)
)
returns decimal(5,2)
reads sql data
begin
	declare total_score decimal(10,2);
	declare course_count int;
    select sum(score), count(*) into total_score, course_count from grade where gsno = fsno;
    if course_count > 0 then
		return total_score / course_count;
	else
		return 0;
	end if;
end;
//
delimiter ;

delimiter //
create trigger update_ave_grade_insert
after insert on grade
for each row
begin
	declare ave_score decimal(5,2);
    set ave_score = cal_ave_score(new.gsno);
    update student set sgrade = ave_score where sno = new.gsno;
end;
//
delimiter ;

delimiter //
create trigger update_ave_grade_update
after update on grade
for each row
begin
	declare ave_score decimal(5,2);
    set ave_score = cal_ave_score(new.gsno);
    update student set sgrade = ave_score where sno = new.gsno;
end;
//
delimiter ;

delimiter //
create trigger update_ave_grade_delete
after delete on grade
for each row
begin
	declare ave_score decimal(5,2);
    set ave_score = cal_ave_score(old.gsno);
    update student set sgrade = ave_score where sno = old.gsno;
end;
//
delimiter ;

-- delimiter //
-- create trigger before_student_delete
-- before delete on student
-- for each row
-- begin
-- 	delete from major_change where csno = old.sno;
--     delete from grade where gsno = old.sno;
--     delete from award_punish where asno = old.sno;
-- end;
-- //
-- delimiter ;

delimiter //
create procedure delete_student(
	psno char(8)
)
begin
	delete from major_change where csno = psno;
	delete from grade where gsno = psno;
	delete from award_punish where asno = psno;
	delete from student where sno = psno;
end;
//
delimiter ;

insert into major values ('M000', 'cs');
insert into major values ('M001', 'ds');
insert into major values ('M002', 'chem');
insert into major values ('M003', 'bio');

insert into course values ('C000', 'ai');
insert into course values ('C001', 'db');
insert into course values ('C002', 'alg');
insert into course values ('C003', 'nlp');

insert into student (sno, sname, sex, smno, syear) values('S000', 'riven', 'female', 'M000', 2000);
insert into student (sno, sname, sex, smno, syear) values('S001', 'amumu', 'walmart bag', 'M000', 2001);
insert into student (sno, sname, sex, smno, syear) values('S002', 'yasuo', 'male', 'M002', 2000);
insert into student (sno, sname, sex, smno, syear) values('S003', 'jinx', 'female', 'M002', 2001);

insert into grade values ('S000', 'C000', 70);
insert into grade values ('S000', 'C001', 80);
insert into grade values ('S000', 'C003', 85);
insert into grade values ('S001', 'C000', 50);
insert into grade values ('S001', 'C002', 70);
insert into grade values ('S002', 'C000', 90);
insert into grade values ('S002', 'C001', 80);
insert into grade values ('S002', 'C002', 70);
insert into grade values ('S003', 'C001', 50);
insert into grade values ('S003', 'C002', 70);

call change_major('S000', 'M001', 2001);
call change_major('S000', 'M002', 2002);
call change_major('S001', 'M003', 2001);
call change_major('S002', 'M003', 2001);

call insert_award_punish('S000', '奖励一个大逼兜');
call insert_award_punish('S000', '给你两个大逼兜');
call insert_award_punish('S001', '奖励一个大逼兜');
call insert_award_punish('S002', '给你两个大逼兜');
call insert_award_punish('S002', '奖励一个大逼兜');
call insert_award_punish('S003', '给你三个大逼兜');

-- select * from award_punish;
-- insert into course values ('C000', 'ai');
-- insert into course values ('C001', 'db');
-- insert into grade values ('S000', 'C000', 10);
-- insert into course values ('C002', 'ds');
-- insert into grade values ('S000', 'C001', 15);
-- delete from grade where gsno = 'S000' and gcno = 'C000';
-- update grade set score = 20 where gsno = 'S000' and gcno = 'C001';

-- call delete_student('S000');
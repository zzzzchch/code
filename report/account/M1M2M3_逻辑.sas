/*option validvarname=any;option compress=yes;*/
/*libname repayFin "E:\guan\中间表\repayfin";*/
/*libname zq "E:\guan\中间表\zq";*/
/*libname account 'E:\guan\原数据\account';*/

*结尾有导出文件操作，需在路径处加上;

data macrodate;
format date  start_date  fk_month_begin month_begin  end_date last_month_end last_month_begin month_end yymmdd10.;*定义时间变量格式;
if day(today())=1 then date=intnx("month",today(),-1,"end");
else date=today()-1;
/*date = mdy(12,31,2017);*/
call symput("tabledate",date);*定义一个宏;
start_date = intnx("month",date,-2,"b");
call symput("start_date",start_date);
month_begin=intnx("month",date,0,"b");
call symput("month_begin",month_begin);
month_end=intnx("month",date,1,"b")-1;
call symput("month_end",month_end);
last_month_end=intnx("month",date,0,"b")-1;
call symput("last_month_end",last_month_end);
last_month_begin=intnx("month",date,-1,"b");
call symput("last_month_begin",last_month_begin);
if day(date)>25 then do; fk_month_begin = mdy(month(date),26,year(date));*当月26-下月25的循环;
end_date = mdy(month(date)+1,25,year(date));end;
else do;fk_month_begin = mdy(month(date)-1,26,year(date));
end_date = mdy(month(date),25,year(date));end;
/*加了一个12月底跟新的一年1月初的情况，不然新年或者月底会出现空值*/
if month(date)=12 and day(date)>25 then do; fk_month_begin = mdy(month(date),26,year(date));*当月26-下月25的循环;
end_date = mdy(month(date)-11,25,year(date)+1);end;
else if month(date)=1 and day(date)<=25 then do;fk_month_begin = mdy(month(date)+11,26,year(date)-1);
end_date = mdy(month(date),25,year(date));end;
call symput("fk_month_begin",fk_month_begin);
call symput("end_date",end_date);
run;
*-----------------------------------------------------------------每天M1M2、M2M3客户**发朱琨用-------------------------------------------------------------------------------------*;
data aa;
format dt  yymmdd10.;
format dtt  $20. ;
 dt = today() - 1;
 dtt=compress(put(dt,yymmdd10.),"-");
call symput("dtt", dtt);
call symput("dt", dt);
run;

%put &dtt.;
/*%let dtt=mdy(12,31,2017);*/


/*看本月M1M2客户，是全部的*/
data kank_1;
set repayFin.payment_daily(where=(cut_date=&dt.));
if contract_no="C2017090517364935629487" and month="201809" then delete ;
if 还款_上月底M1=1 and 营业部^="APP";
keep CONTRACT_NO 资金渠道 客户姓名 营业部 贷款余额_1月前_M1 ;
run;
data kank;
set repayFin.payment_daily;

if 还款_上月底M1=1;
if 还款_M1M2^=1;
keep CONTRACT_NO  贷款余额 cut_date ;
rename  cut_date=还款日期;
run;
/*clear_date是有毛病的，当逾期天数>30天时，客户欠了两笔，还了第一笔之后，repay_date会自动跳到下一个账单日，
clear_date会变成0，为了得到结清日期，当还款_M1M2由1变成0的时候，cut_date会等于结清日期
逻辑是：还款_M1M2^=1,第一条还款_M1M2=0的就是结清日期，后面的去重就可以*/
proc sort data = kank ;by contract_no  ;run; 
proc sort data = kank out = kank1 nodupkey;by contract_no;run; 
proc sort data = kank1 ;by 还款日期;run; 

proc sql;
create table kank_ as 
select a.*,b.*
from kank_1 as a
left join kank1 as b
on a.contract_no=b.contract_no;
quit;

proc sort data=kank_;by  descending 还款日期;run;

data kankk_1;
set repayFin.payment_daily(where=(cut_date=&dt.));
if 还款_上月底M2=1 and 营业部^="APP";
keep CONTRACT_NO 资金渠道 客户姓名 营业部 贷款余额_1月前_M2_r ;
run;
/*不同资金渠道分开求还款日期*/
data kankk__1;
set repayFin.payment_daily(where=(cut_date=&dt.));
if 还款_上月底M2=1 and 营业部^="APP";
if 还款_M2M3^=1 ;
if 资金渠道 not in ("jsxj1");
keep CONTRACT_NO 资金渠道 贷款余额 ;
run;
/*data kankk__2;*/
/*set repayFin.payment_daily(where=(cut_date=&dt.));*/
/*if 还款_上月底M2=1 and 营业部^="APP";*/
/*if 还款_M2M3^=1 ;*/
/*if 资金渠道 ="xyd1";*/
/*keep CONTRACT_NO 资金渠道 贷款余额 ;*/
/*run;*/
data kankk__3;
set repayFin.payment_daily(where=(cut_date=&dt.));
if 还款_上月底M2=1 and 营业部^="APP";
if 还款_M2M3^=1 ;
if 资金渠道 ="jsxj1";
keep CONTRACT_NO 资金渠道 贷款余额 ;
run;
data kankk__;
set kankk__1  kankk__3;
run;
/*取还款日期,取dtl的最后一个日期作为还款日期,小雨点,晋商用另外的两个表*/
proc sql;
create table kankk1 as
select a.*,b.OFFSET_DATE as 还款日期
from kankk__1  as a
left join zq.bill_fee_dtl(where=(FEE_NAME in ("本金","利息"))) as b
on a. contract_no=b.CONTRACT_NO
where OFFSET_DATE<=&dt.;
quit;
proc sort data=kankk1 ;by contract_no descending 还款日期;run;
proc sort data=kankk1 nodupkey;by contract_no;run;
/*proc sql;*/
/*create table kankk2 as*/
/*select a.*,b.clear_date as 还款日期*/
/*from kankk__2  as a*/
/*left join repayfin.Tttrepay_plan_xyd as b*/
/*on a. contract_no=b.CONTRACT_NO;*/
/*quit;*/
/*proc sort data=kankk2 ;by contract_no descending 还款日期;run;*/
/*proc sort data=kankk2 nodupkey;by contract_no;run;*/
proc sql;
create table kankk3 as
select a.*,b.clear_date_js as 还款日期
from kankk__3  as a
left join repayfin.Tttrepay_plan_js as b
on a. contract_no=b.CONTRACT_NO;
quit;
proc sort data=kankk3 ;by contract_no descending 还款日期;run;
proc sort data=kankk3 nodupkey;by contract_no;run;
data kankk;
set kankk1  kankk3;
run;



proc sql;
create table kankk_ as 
select a.* ,b.*,c.还款日期
from kankk_1 as a 
left join kankk__ as b on a.contract_no=b.contract_no
left join kankk as c on  a.contract_no=c.contract_no;
quit;
proc sort data=kankk_;by  descending 还款日期;run;

/*data kankk_;*/
/*set kankk_;*/
/*/*手动修复对公延迟客户*/*/
/*if contract_no in ("C2017080410211770435844","C2017113013252201372210") then 还款日期=mdy(5,31,2018);*/
/*run;*/
/*data kankk_;*/
/*set kankk_;*/
/*if 还款日期<&month_begin. then do;*/
/*还款日期="";*/
/*贷款余额="";*/
/*end;*/
/*run;*/*/;

data bill_month;
set repayfin.payment_daily(where=(cut_date=&dt.));
if 营业部^="APP";
if &month_begin.<=repay_date<=&month_end.;
if clear_date>0;
keep contract_no 客户姓名 REPAY_DATE CLEAR_DATE  ;
run;
proc sort data=aa;by  REPAY_DATE CLEAR_DATE  ;run;

*导出文件已移至最后;

/*PROC EXPORT DATA=kank_*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M1M2还款客户"; RUN;*/
/*PROC EXPORT DATA=kankk_*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M2M3还款客户"; RUN;*/
/*PROC EXPORT DATA=bill_month*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="当月账单还款客户列表"; RUN;*/

*---------------------------------------------------------------穆卿m1、m2分子-----------------------------------------------------------------------*;
data mm1;
set repayfin.payment_daily(where=(cut_date=&dt.));
if 还款_M1合同贷款余额>0;
if 营业部^="APP";
keep   contract_no 客户姓名 营业部 贷款余额_剩余本金部分 贷款余额 od_days 资金渠道;
run;

data mm2;
set repayfin.payment_daily(where=(cut_date=&dt.));
if 还款_M2合同贷款余额>0;
if 营业部^="APP";
keep   contract_no 客户姓名 营业部 贷款余额_剩余本金部分 贷款余额 od_days 资金渠道;
run;

*导出文件已移至最后;
/*PROC EXPORT DATA=mm1*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\穆卿\当前M1及M2客户明细_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M1客户明细"; RUN;*/
/*PROC EXPORT DATA=mm2*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\穆卿\当前M1及M2客户明细_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M2客户明细"; RUN;*/

*---------------------------------------------------------------部分还款客户-----------------------------------------------------------------------*;
data aa;
set repayfin.payment_daily(where=(cut_date=&dt.));
if 营业部^="APP";
if 还款_M2合同贷款余额>0;
run;
*找出属于晋商的客户;
data aa1;
set aa;
if 资金渠道="jsxj1";
run;
*找出晋商该月的月还;
data aaa1;
set repayfin.Tttrepay_plan_js;
if &last_month_begin.<=repay_date_js<=&month_end.;
已还本息=SETLPRCP+SETLNORMINT;
run;
proc sql;
create table aaa1_ as
select contract_no,sum(已还本息) as 已还本息
from aaa1
group by contract_no;
quit;
proc sort data=aaa1_ nodupkey ;by contract_no;run;
proc sql;
create table aa_js as 
select a.*,b.已还本息 
from aa1 as a
left join aaa1_ as b
on a.contract_no=b.contract_no;
quit;
*找出晋商以外的客户;
data aa2;
set aa;
if 资金渠道^="jsxj1";
run;
*找出晋商以外的客户月还;
proc sql;
create table aaa2 as 
select a.*,b.REPAY_DATE
from account.bill_fee_dtl as a 
left join account.repay_plan as b
on a.contract_no=b.contract_no and a.CURR_PERIOD=b.CURR_PERIOD;
quit;

proc sql;
create table aaa2_ as 
select contract_no ,sum(curr_receipt_amt) as 已还本息
from aaa2
where   &last_month_begin.<=REPAY_DATE<=&month_end.
group by contract_no;
quit;
proc sql;
create table aa_qita as
select a.*,b.已还本息
from aa2 as a
left join aaa2_ as b 
on a.contract_no=b.contract_no;
quit;

data aa_;
set aa_js aa_qita;
if 已还本息>0;
keep contract_no 客户姓名 已还本息;
run;

/*PROC EXPORT DATA=kank_*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M1M2还款客户"; RUN;*/
/*PROC EXPORT DATA=kankk_*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M2M3还款客户"; RUN;*/
/*PROC EXPORT DATA=bill_month*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="当月账单还款客户列表"; RUN;*/
/**/
/*PROC EXPORT DATA=mm1*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\穆卿\当前M1及M2客户明细_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M1客户明细"; RUN;*/
/*PROC EXPORT DATA=mm2*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\穆卿\当前M1及M2客户明细_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="M2客户明细"; RUN;*/
/**/
/*PROC EXPORT DATA=aa_*/
/*OUTFILE= "E:\guan\日监控临时报表\M1M2M3\朱琨\M1M2-M2M3_&dtt..xls" DBMS=EXCEL REPLACE;SHEET="部分还款客户名单"; RUN;*/

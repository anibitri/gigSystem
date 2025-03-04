COPY act (actid, actname, genre, standardfee) FROM stdin;
1	QLS	Rock	29000
2	The Where	Music	13000
3	Join Division	Music	1000
4	The Selecter	Music	28000
5	Scalar Swift	Music	30000
6	ViewBee 40	Music	31000
\.

COPY venue (venueid, venuename, hirecost, capacity) FROM stdin;
1	Big Hall	14000	1000
2	Arts Centre Theatre	5000	300
3	City Hall	8000	500
4	Village Green	3000	120
5	Village Hall	2000	80
6	Cinema	6000	300
7	Symphony Hall	20000	2000
8	Town Hall	10000	800
\.

COPY gig (gigid, venueid, gigtitle, gigdatetime, gigstatus) FROM stdin;
1	6	Test title	2018-12-11 19:00:00	G
2	6	Test title	2019-03-08 20:00:00	G
3	7	Test title	2017-09-07 19:00:00	G
4	5	Test title	2020-04-06 18:00:00	G
5	4	Another gig	2019-04-08 22:00:00	G
\.

COPY act_gig (actid, gigid, actgigfee, ontime, duration) FROM stdin;
2	1	13000	2018-12-11 20:15:00	20
3	1	1000	2018-12-11 20:45:00	80
5	2	30000	2019-03-08 20:00:00	30
1	2	29000	2019-03-08 20:40:00	50
5	4	30000	2020-04-06 18:00:00	80
1	5	23000	2019-04-08 22:00:00	60
5	1	30000	2018-12-11 19:00:00	60
3	2	1000	2019-03-08 21:45:00	60
5	3	22000	2017-09-07 19:00:00	30
6	3	22000	2017-09-07 19:40:00	30
\.

COPY gig_ticket (gigid, pricetype, price) FROM stdin;
1	A	40
4	A	40
2	A	40
3	A	40
\.

COPY ticket (ticketid, gigid, customername, customeremail, pricetype, cost) FROM stdin;
1	4	J Smith	jsmith@example.com	A	40
2	3	J Smith	jsmith@example.com	A	40
3	3	G Jones	gjones@example.com	A	40
4	1	G Jones	gjones@example.com	A	40
5	2	G Jones	gjones@example.com	A	40
6	2	N McConnell	nmcconnell@example.com	A	40
7	4	G Jones	gjones@example.com	A	40
8	4	G Jones	gjones@example.com	A	40
\.


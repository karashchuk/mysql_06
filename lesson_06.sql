-- -- Практическое задание по теме “Операторы, фильтрация, сортировка и ограничение. 
-- Агрегация данных”

-- Работаем с БД vk и тестовыми данными, которые вы сгенерировали ранее:

-- 1. Проанализировать запросы, которые выполнялись на занятии, определить возможные 
-- корректировки и/или улучшения (JOIN пока не применять).

-- Предложение по запросу:

-- Объединяем медиафайлы пользователя и его друзей для создания ленты новостей
SELECT filename, user_id, created_at FROM media WHERE user_id = 3
UNION
SELECT filename, user_id, created_at FROM media WHERE user_id IN (
  (SELECT friend_id 
  FROM friendship 
  WHERE user_id = 3
    AND confirmed_at IS NOT NULL 
    AND status_id IN (
      SELECT id FROM friendship_statuses 
        WHERE name = 'Confirmed'
    )
  )
  UNION
  (SELECT user_id 
    FROM friendship 
    WHERE friend_id = 3
      AND confirmed_at IS NOT NULL 
      AND status_id IN (
      SELECT id FROM friendship_statuses 
        WHERE name = 'Confirmed'
    )
  )
);
-- здесь часто повторяется одна и та же ссылка на user_id, и если например мне надо будет выполнить аналогичный запрос на другого пользователя, то придется менять user_id в нескольких местах, кроме того можно где-то пропустить.
-- Предложение 1: ввести переменную:
select @ui := 21;
-- тогда запрос будет универсальный:
SELECT filename, user_id, created_at FROM media WHERE user_id = @ui
UNION
SELECT filename, user_id, created_at FROM media WHERE user_id IN (
  (SELECT friend_id 
  FROM friendship 
  WHERE user_id = @ui
    AND confirmed_at IS NOT NULL 
    AND status_id IN (
      SELECT id FROM friendship_statuses 
        WHERE name = 'Confirmed'
    )
  )
  UNION
  (SELECT user_id 
    FROM friendship 
    WHERE friend_id = @ui
      AND confirmed_at IS NOT NULL 
      AND status_id IN (
      SELECT id FROM friendship_statuses 
        WHERE name = 'Confirmed'
    )
  )
);
-- Предложение 2. При указанном подходе мы можем для указания переменной пользоваться сразу запросом по имени и фамилии:
Select @ui := 
	(Select id 	from users where first_name like 'Alexys' and last_name like 'Hartmann' );

-- аналогично это можно использовать и в других запроссах рассмотренных далее

-- Предложение 3 по запросу (почему то не работает один из запросов в примере):
-- Архив с правильной сортировкой новостей по месяцам
SELECT COUNT(id) AS news, 
  MONTHNAME(created_at) AS month,
  MONTH(created_at) AS month_num 
    FROM media
    GROUP BY month_num
    ORDER BY month_num DESC;
-- при запуске ругается:
-- SQL Error [1055] [42000]: Expression #2 of SELECT list is not in GROUP BY clause and contains nonaggregated column 'vk.media.created_at' which is not functionally dependent on columns in GROUP BY clause; this is incompatible with sql_mode=only_full_group_by
-- Если строку   MONTHNAME(created_at) AS month, задизейблить, то все нормально, или вторую строку (  MONTH(created_at) AS month_nu), при этом группировку и сортировку перекинув на первую выборку по месяцам, то все нормально запрос работает.
-- хотя на вебинаре все работало.
-- у меня подозрение что это скорее всего связано с тем что у вас был MySQL 5.7, а у меня стоит MySQL 8
-- Решение проблемы - добавить в группировку алиас и второго столбца (хотя по сути это одно и тоже):
SELECT COUNT(id) AS news, 
  MONTHNAME(created_at) AS month,
  MONTH(created_at) AS month_num 
    FROM media
    GROUP BY month_num, month
    ORDER BY month_num DESC;
	


-- 2. Пусть задан некоторый пользователь. 
-- Из всех друзей этого пользователя найдите человека, который больше всех общался 
-- с нашим пользователем.

select 
	from_user_id,
	(SELECT CONCAT(first_name, ' ', last_name)
    FROM users WHERE id = messages.from_user_id) as username,
	count(*) as quantity 
from messages 
where to_user_id = 21 
group by from_user_id 
ORDER BY quantity DESC 
LIMIT 1;



-- 3. Подсчитать общее количество лайков, которые получили 10 самых молодых пользователей.

-- создаем вспомогательную таблицу - определяем 10 самых молодых пользователей:

DROP TABLE IF EXISTS young;
CREATE TABLE young (
  id INT);

INSERT INTO young 
  (SELECT id
   from users
   ORDER by (Select birthday from profiles where user_id = users.id) desc
   LIMIT 10);

select * from young;

-- создаем вспомогательную таблицу всех активностей молодых пользоватлей
DROP TABLE IF EXISTS acts_young;
CREATE TABLE acts_young (
  user_id INT,
  target_id INT,
  target_type_id INT);

INSERT INTO acts_young 
(
	(Select  -- это сколько создали медиафайлов молодые пользователи 
		user_id,
		id as target_id, 
		(Select id FROM target_types where name like 'media') as target_type_id
	from media
	where user_id in (SELECT id from young))
UNION
	(Select -- это сколько создали посланий молодые пользователи 
		from_user_id as user_id,
		id as target_id, 
		(Select id FROM target_types where name like 'messages') as target_type_id
	from messages
	where from_user_id in (SELECT id from young))
UNION
	(Select  -- это сколько создали своих учеток молодые пользователи 
		id as user_id,
		id as target_id, 
		(Select id FROM target_types where name like 'users') as target_type_id
	from users
	where id in (SELECT id from young))
UNION
	(Select -- это сколько создали постов молодые пользователи 
		user_id,
		id as target_id, 
		(Select id FROM target_types where name like 'posts') as target_type_id
	from posts
	where user_id in (SELECT id from young))
);

-- тогда общее количество лайков, которые получили 10 самых молодых пользователей: 
SElect count(*) from
(SELECT  -- здесь берем только те лайки, которые ссылаются на записи в нашей вспомогательной таблице acts_young
	id,
	(Select target_id from acts_young where target_id = likes.target_id and target_type_id = likes.target_type_id) as ti
from likes 
where (Select target_id from acts_young where target_id = likes.target_id and target_type_id = likes.target_type_id) is not NULL) as ll;


-- 4. Определить кто больше поставил лайков (всего) - мужчины или женщины?
select 
	(Select sex from profiles where user_id = likes.user_id) as sex,
	count(user_id) as quantity
from likes
group by sex
ORDER by quantity desc;


-- 5. Найти 10 пользователей, которые проявляют наименьшую активность в использовании 
-- социальной сети.
-- под проявлением активности будем понимать: 
-- 1. создание учетки (это минимально что может сделать пользователь чтобы участвовать в соцсетях)
-- 2. создание постов
-- 3. создние медиа файлов
-- 4. создание сообщений
-- 5. создание лайков
-- 6. создание запросов на дружбу  

-- создадим сводную таблицу по всем активностям пользователей:
DROP TABLE IF EXISTS acts;
CREATE TABLE acts(
  user_id INT,
  qty INT);
-- вставим в нее количество активностей по каждой из таблиц:
INSERT INTO acts 
(select 
		user_id, 
		count(*) as qty
	from posts
	GROUP BY user_id
	ORDER by qty)
UNION	
	(select 
		id as user_id, 
		count(*) as qty
	from users
	GROUP BY user_id
	ORDER by qty)
UNION	
	(select 
		user_id, 
		count(*) as qty
	from media
	GROUP BY user_id
	ORDER by qty)
UNION	
	(select 
		from_user_id as user_id, 
		count(*) as qty
	from messages
	GROUP BY user_id
	ORDER by qty)
UNION	
	(select 
		user_id, 
		count(*) as qty
	from likes
	GROUP BY user_id
	ORDER by qty)
UNION	
	(select 
		user_id, 
		count(*) as qty
	from friendship
	GROUP BY user_id
	ORDER by qty)
;

-- теперь можно вывести сводное количество активностей по всем пользователям с сортировкой по возрастанию и отсечкой на первые 10 пользователей:
select 
	user_id,
	(select CONCAT(first_name, ' ', last_name) from users where id = acts.user_id) as username,
	count(qty) as qty
from acts
GROUP by user_id
ORDER by qty
LIMIT 10;

-- ДОПОЛНЕНИЕ к заданию 5:
-- 1. Оптимизация:
-- В случае большого количества данных нам необязательно набирать общую таблицу всех активностей из всех таблиц, так как нам необходимо выбрать только 10 наименее активных	пользователей, то из каждой таблицы достаточно выбирать только первые 50 записей по нименьшим активностям (50 берется из расчета что надо найти 10 пользователей по 5 таблицам). берем не только первые 10 а 50 по причине того что надо искать суммарно повсем таблицам).
-- 2. Работа с ограничением по времени.
-- В случае если задача будет стоять что наименьшая активность за последний год например, то необходимо в выборку активностей добавить еще фильтр по последнему году. Но при этом могут не попасть записи по созданию учетки, и тогда могут быть пользователи у которых за последний год совсем не было активности. Такая проблема решается тем, что запрос берем относительно таблицы users и там сравниваем с активностями. В этом случае могут появиться и Null по тем пользователям у которых совсем не было активности за последний год. Сортируем по активностям учитывая и Null как 0.


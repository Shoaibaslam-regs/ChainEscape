class_name DailyDate
extends RefCounted
## Calendar helpers for the Daily challenge. Dates are "YYYY-MM-DD" keys in
## the device's local time (works offline). Day numbers count days since
## 1970-01-01 and make streak arithmetic simple.

const SECONDS_PER_DAY := 86400
const WEEKDAYS: Array[String] = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const MONTHS: Array[String] = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]


static func today_key() -> String:
	var now := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [now["year"], now["month"], now["day"]]


static func is_valid(key: String) -> bool:
	var parts := key.split("-")
	return parts.size() == 3 and parts[0].is_valid_int() and parts[1].is_valid_int() and parts[2].is_valid_int()


static func to_day_number(key: String) -> int:
	var parts := key.split("-")
	var unix := Time.get_unix_time_from_datetime_dict({
		"year": parts[0].to_int(), "month": parts[1].to_int(), "day": parts[2].to_int(),
		"hour": 12, "minute": 0, "second": 0,
	})
	return int(unix / SECONDS_PER_DAY)


static func from_day_number(day_number: int) -> String:
	var date := Time.get_date_dict_from_unix_time(day_number * SECONDS_PER_DAY + SECONDS_PER_DAY / 2)
	return "%04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


static func add_days(key: String, days: int) -> String:
	return from_day_number(to_day_number(key) + days)


## 0 = Sunday … 6 = Saturday.
static func weekday(key: String) -> int:
	return Time.get_date_dict_from_unix_time(to_day_number(key) * SECONDS_PER_DAY + SECONDS_PER_DAY / 2)["weekday"]


## e.g. "Tuesday, 24 November".
static func long_label(key: String) -> String:
	var parts := key.split("-")
	return "%s, %d %s" % [WEEKDAYS[weekday(key)], parts[2].to_int(), MONTHS[parts[1].to_int() - 1]]


## e.g. "NOV 24".
static func short_label(key: String) -> String:
	var parts := key.split("-")
	return "%s %d" % [MONTHS[parts[1].to_int() - 1].substr(0, 3).to_upper(), parts[2].to_int()]


## Seconds until local midnight, when the next puzzle unlocks.
static func seconds_until_tomorrow() -> int:
	var now := Time.get_time_dict_from_system()
	return SECONDS_PER_DAY - (now["hour"] * 3600 + now["minute"] * 60 + now["second"])

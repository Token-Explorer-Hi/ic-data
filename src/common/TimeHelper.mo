module {

    public func get_month(tx_time : Nat) : Nat {
        return _get_month(tx_time);
    };

    func _get_month(tx_time : Nat) : Nat {
        let _MILLISECONDS_PER_DAY : Nat = 24 * 60 * 60 * 1000;
        let _DAYS_IN_MONTH_NON_LEAP : [Nat] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        let _DAYS_IN_MONTH_LEAP : [Nat] = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
        var timestamp = tx_time;
        var year = 1970;
        var millisecondsInYear = 365 * _MILLISECONDS_PER_DAY;
        let daysInMonthNonLeap = _DAYS_IN_MONTH_NON_LEAP;
        let daysInMonthLeap = _DAYS_IN_MONTH_LEAP;

        while (timestamp >= millisecondsInYear) {
            if (_is_leap_year(year)) {
                millisecondsInYear := 366 * _MILLISECONDS_PER_DAY;
            }else{
                millisecondsInYear := 365 * _MILLISECONDS_PER_DAY;
            };
            timestamp := timestamp - millisecondsInYear;
            year+=1;
        };

        var month = 0;
        let daysInMonth = if (_is_leap_year(year)) {
            daysInMonthLeap
        }else{
            daysInMonthNonLeap
        };
        var daysRemaining = timestamp / _MILLISECONDS_PER_DAY;
        label l loop {
            while (month < 12) {
                if (daysRemaining < daysInMonth[month]) {
                    break l;
                };
                daysRemaining := daysRemaining - daysInMonth[month];
                month := month + 1;
            };
        };
        return year * 100 + (month+1);
    };

    func _is_leap_year(year: Nat) : Bool {
        return (year % 4 == 0 and year % 100 != 0) or year % 400 == 0;
    };
}
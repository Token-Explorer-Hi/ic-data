import Hash "mo:base/Hash";
import Nat32 "mo:base/Nat32";
import Order "mo:base/Order";
import Array "mo:base/Array";


module{

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
    
    public func _hash_nat8(key : [Nat32]) : Hash.Hash {
        var hash : Nat32 = 0;
        for (nat_of_key in key.vals()) {
            hash := hash +% nat_of_key;
            hash := hash +% hash << 10;
            hash := hash ^ (hash >> 6);
        };
        hash := hash +% hash << 3;
        hash := hash ^ (hash >> 11);
        hash := hash +% hash << 15;
        return hash;
    };

    public func hash(n : Nat) : Hash.Hash {
        let j = Nat32.fromNat(n);
        _hash_nat8([
            j & (255 << 0),
            j & (255 << 8),
            j & (255 << 16),
            j & (255 << 24),
        ]);
    };

    public func sort<A>(xs : [A], cmp : (A, A) -> Order.Order) : [A] {
        let tmp : [var A] = Array.thaw(xs);
        sortInPlace(tmp, cmp);
        Array.freeze(tmp)
    };

    public func sortInPlace<A>(xs : [var A], cmp : (A, A) -> Order.Order) {
        if (xs.size() < 2) return;
        let aux : [var A] = Array.tabulateVar<A>(xs.size(), func i { xs[i] });

        func merge(lo : Nat, mid : Nat, hi : Nat) {
            var i = lo;
            var j = mid + 1;
            var k = lo;
            while(k <= hi) {
                aux[k] := xs[k];
                k += 1;
            };
            k := lo;
            while(k <= hi) {
                if (i > mid) {
                    xs[k] := aux[j];
                    j += 1;
                } else if (j > hi) {
                    xs[k] := aux[i];
                    i += 1;
                } else if (Order.isLess(cmp(aux[j], aux[i]))) {
                    xs[k] := aux[j];
                j += 1;
                } else {
                    xs[k] := aux[i];
                    i += 1;
                };
                k += 1;
            };
        };

        func go(lo : Nat, hi : Nat) {
            if (hi <= lo) return;
            let mid : Nat = lo + (hi - lo) / 2;
            go(lo, mid);
            go(mid + 1, hi);
            merge(lo, mid, hi);
        };
        go(0, xs.size() - 1);
    };
}
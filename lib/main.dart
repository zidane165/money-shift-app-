import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/cupertino.dart';

import 'dart:convert';

void main() {
  runApp(const MoneyApp());
}

// シフトデータ管理のクラス
class ShiftRecord {
  int amount;
  DateTime date;
  String jobName;

  ShiftRecord({
    required this.amount, //金額
    required this.date, //日付
    required this.jobName, //仕事名
  });
  Map<String, dynamic> toJson() => {
    'amount': amount,
    //日付を文字列に変換して保存
    'date': date.toIso8601String(),
    'jobName': jobName,
  };

  factory ShiftRecord.fromJson(Map<String, dynamic> json) => ShiftRecord(
    amount: json['amount'],
    //文字列からDateTime型に復元
    date: DateTime.parse(json['date']),
    jobName: json['jobName'],
  );
}

// 仕事の詳細のためのクラス
class Job {
  String name; //仕事名
  int hourlyWage; //時給
  int closingDay; //締め日
  int payDay; //給料日
  Color color; //カラー

  Job({
    required this.name,
    required this.hourlyWage,
    required this.closingDay,
    required this.payDay,
    required this.color,
  });

  //解体用：Json
  Map<String, dynamic> toJson() => {
    'name': name,
    'hourlyWage': hourlyWage,
    'closingDay': closingDay,
    'payDay': payDay,
  };
  //組み立て
  factory Job.fromJson(Map<String, dynamic> json) => Job(
    name: json['name'],
    hourlyWage: json['hourlyWage'],
    closingDay: json['closingDay'],
    payDay: json['payDay'],
    color: Colors.blue,
  );
}

//支出を扱うクラス
class ExpenseRecord {
  int amount; //金額
  DateTime date; //お金が減る日
  String title; //出費項目

  ExpenseRecord({
    required this.amount,
    required this.date,
    required this.title,
  });
  Map<String, dynamic> toJson() => {
    'amount': amount,
    'date': date.toIso8601String(),
    'title': title,
  };

  factory ExpenseRecord.fromJson(Map<String, dynamic> json) => ExpenseRecord(
    amount: json['amount'],
    date: DateTime.parse(json['date']),
    title: json['title'],
  );
}

//サブスク・固定費を管理するクラス
class Subscription {
  String title;
  int amount;
  int billingDay; // 毎月何日に引き落とされるか

  Subscription({
    required this.title,
    required this.amount,
    required this.billingDay,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'amount': amount,
    'billingDay': billingDay,
  };

  factory Subscription.fromJson(Map<String, dynamic> json) => Subscription(
    title: json['title'],
    amount: json['amount'],
    billingDay: json['billingDay'],
  );
}

//ページタイトルのクラス
class MoneyApp extends StatelessWidget {
  const MoneyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '収支管理アプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final TextEditingController controller =
      TextEditingController(); //ターミナル用金額テキスト出力コントローラー
  final TextEditingController jobcontroller =
      TextEditingController(); //仕事用テキストコントローラー
  final TextEditingController newJobNameController =
      TextEditingController(); //新規仕事名用コントローラー
  final TextEditingController newJobWageController =
      TextEditingController(); //新規仕事賃金用コントローラー
  final TextEditingController balanceController =
      TextEditingController(); //所持金入力用コントローラー
  final TextEditingController expenseTitleController =
      TextEditingController(); //支出名目用コントローラー
  final TextEditingController expenseAmountController =
      TextEditingController(); //支出金額用コントローラー
  final TextEditingController newJobClosingDayController =
      TextEditingController(); //締め日用コントローラー
  final TextEditingController newJobPayDayController =
      TextEditingController(); //給料日用コントローラー

  DateTime _focusedDay = DateTime.now(); // 表示している月・日
  DateTime? _selectedDay; // ユーザーがタップして選択した日

  DateTime selectedDate = DateTime.now(); //日付を保存する変数
  List<ShiftRecord> records = []; //収入の記録を保存させるリスト
  List<ExpenseRecord> expenses = []; //支出の記録を保存させるリスト
  List<Job> myjobs = []; //仕事の詳細を保存させるリスト
  List<Subscription> subscriptions = []; //サブスクのリスト

  Job? selectedJob; //Job型もしくはまだ選ばれてないならnull型の選ばれた仕事を保存する変数

  TimeOfDay? startTime; //開始時間
  TimeOfDay? endTime; //終了時間

  int _selectedIndex = 0;

  int balance = 0; //実残高変数

  //ローカル保存
  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      // 'my_balance' という鍵で保存された数字を探し、まだ保存されていなければ0に
      balance = prefs.getInt('my_balance') ?? 0;
    });
    String? jobsJson = prefs.getString('my_jobs_key'); //文字列を取り出す

    if (jobsJson != null) {
      List<dynamic> decodedList = jsonDecode(jobsJson); // JSONを解凍
      setState(() {
        // 解凍したデータをJobクラスの形に組み立て直してリストに上書き
        myjobs = decodedList.map((item) => Job.fromJson(item)).toList();
      });
    }
    //シフト履歴の読み込み
    String? recordsJson = prefs.getString('my_records_key');
    if (recordsJson != null) {
      List<dynamic> decoded = jsonDecode(recordsJson);
      setState(() {
        records = decoded.map((item) => ShiftRecord.fromJson(item)).toList();
      });
    }

    //支出履歴の読み込み
    String? expensesJson = prefs.getString('my_expenses_key');
    if (expensesJson != null) {
      List<dynamic> decoded = jsonDecode(expensesJson);
      setState(() {
        expenses = decoded.map((item) => ExpenseRecord.fromJson(item)).toList();
      });
    }

    //サブスクの読み込み
    String? subJson = prefs.getString('my_subscriptions_key');
    if (subJson != null) {
      List<dynamic> decoded = jsonDecode(subJson);
      setState(() {
        subscriptions = decoded
            .map((item) => Subscription.fromJson(item))
            .toList();
      });
    }
  }

  // シフト履歴を保存する関数
  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(records.map((r) => r.toJson()).toList());
    await prefs.setString('my_records_key', jsonString);
  }

  // 支出履歴を保存する関数
  Future<void> _saveExpenses() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(expenses.map((e) => e.toJson()).toList());
    await prefs.setString('my_expenses_key', jsonString);
  }

  // 仕事マスターを保存する関数
  Future<void> _saveJobs() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(myjobs.map((j) => j.toJson()).toList());
    await prefs.setString('my_jobs_key', jsonString);
  }

  //サブスクを保存する関数
  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    String jsonString = jsonEncode(
      subscriptions.map((s) => s.toJson()).toList(),
    );
    await prefs.setString('my_subscriptions_key', jsonString);
  }

  // 月初めの確認と修正ダイアログ
  void _showMonthlyCheckDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            DateTime now = DateTime.now();
            // 今月の支出だけを抽出
            List<ExpenseRecord> thisMonthExpenses = expenses
                .where(
                  (e) => e.date.year == now.year && e.date.month == now.month,
                )
                .toList();

            return AlertDialog(
              title: const Text('月初めの確認・調整'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '土日祝の影響で給料日や引き落とし日がズレる場合、タップして修正',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    //給料日の確認・修正
                    const Text(
                      '💰 登録済みの給料日',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (myjobs.isEmpty)
                      const Text('仕事データがありません', style: TextStyle(fontSize: 12)),
                    ...myjobs
                        .map(
                          (job) => ListTile(
                            leading: const Icon(Icons.work),
                            title: Text(job.name),
                            trailing: Text('${job.payDay}日'),
                            onTap: () async {
                              TextEditingController tempController =
                                  TextEditingController(
                                    text: job.payDay.toString(),
                                  );
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('${job.name}の給料日'),
                                  content: TextField(
                                    controller: tempController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '今月の実際の給料日(日)',
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        setState(() {
                                          job.payDay = int.parse(
                                            tempController.text,
                                          );
                                        });
                                        setDialogState(
                                          () {},
                                        ); // 💡 アラート画面の数字も更新
                                        await _saveJobs();
                                        Navigator.pop(context);
                                      },
                                      child: const Text('更新'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),

                    const Divider(),

                    //支出日の確認・修正
                    const Text(
                      '💸 今月の引き落とし予定',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (thisMonthExpenses.isEmpty)
                      const Text(
                        '今月の支出データはありません',
                        style: TextStyle(fontSize: 12),
                      ),
                    ...thisMonthExpenses
                        .map(
                          (exp) => ListTile(
                            leading: const Icon(
                              Icons.shopping_cart,
                              color: Colors.red,
                            ),
                            title: Text(exp.title),
                            subtitle: Text('${exp.amount}円'),
                            trailing: Text('${exp.date.month}/${exp.date.day}'),
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: exp.date,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  exp.date = picked;
                                });
                                setDialogState(() {}); // 💡 アラート画面の日付も更新
                                await _saveExpenses();
                              }
                            },
                          ),
                        )
                        .toList(),

                    //サブスク・固定費の確認・修正
                    const SizedBox(height: 16),
                    const Text(
                      '🔄 サブスク・固定費の引き落とし日',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    if (subscriptions.isEmpty)
                      const Text(
                        '登録されているサブスクはありません',
                        style: TextStyle(fontSize: 12),
                      ),

                    ...subscriptions
                        .map(
                          (sub) => ListTile(
                            leading: const Icon(
                              Icons.autorenew,
                              color: Colors.blue,
                            ),
                            title: Text(sub.title),
                            subtitle: Text('${sub.amount}円'),
                            trailing: Text('${sub.billingDay}日'),
                            onTap: () async {
                              TextEditingController tempController =
                                  TextEditingController(
                                    text: sub.billingDay.toString(),
                                  );
                              await showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('${sub.title}の変更'),
                                  content: TextField(
                                    controller: tempController,
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: '今月の実際の引き落とし日(日)',
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () async {
                                        setState(() {
                                          // 入力された日にちでサブスクマスターの日付を上書き
                                          sub.billingDay = int.parse(
                                            tempController.text,
                                          );
                                        });
                                        setDialogState(() {}); // アラート画面の表示を更新
                                        await _saveSubscriptions(); // 変更を保存
                                        Navigator.pop(context);
                                      },
                                      child: const Text('更新'),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        )
                        .toList(),
                  ],
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('確認完了'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  //扶養の計算のための収入合計関数
  int calculation() {
    int total = 0;
    for (ShiftRecord record in records) {
      total += record.amount;
    }
    return total;
  }

  int maxEarning = 1300000; //扶養の限度額変数の格納

  //給与計算の計算関数
  int salaryCalculation(TimeOfDay start, TimeOfDay end, Job job) {
    int totalMinute =
        (end.hour * 60 + end.minute) - (start.hour * 60 + start.minute);
    if (totalMinute >= 480) {
      totalMinute -= 60;
    } else if (totalMinute >= 360) {
      totalMinute -= 45;
    }
    int actualWage = ((job.hourlyWage / 60) * totalMinute).toInt();
    return actualWage;
  }

  //給料振り込み日の確定関数
  DateTime calulatePayDay(DateTime shiftDate, Job job) {
    //何月分の給料に該当するのかを調べる
    int targetMonth = shiftDate.month;
    //仕事日が締め日より後なら次の月の分の給料になる
    if (shiftDate.day > job.closingDay) {
      targetMonth += 1;
    }
    //給料日が締め日より小さいとき(月で見ると違うが)も次の月の給料になる
    if (job.closingDay > job.payDay) {
      targetMonth += 1;
    }
    return DateTime(shiftDate.year, targetMonth, job.payDay);
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DateTime now = DateTime.now();
      if (now.day <= 5) {
        _showMonthlyCheckDialog();
      }
    });
  }

  //スクロール式（15分刻み）のタイムピッカーを表示する関数
  void _showSpinnerTimePicker(
    BuildContext context,
    StateSetter setModalState,
    bool isStart,
  ) {
    // 初期時間の決定（開始なら9:00、終了なら17:00をデフォルトにする）
    TimeOfDay tempTime = isStart
        ? (startTime ?? const TimeOfDay(hour: 9, minute: 0))
        : (endTime ?? const TimeOfDay(hour: 17, minute: 0));

    // エラー防止: 15分間隔のピッカーには、15の倍数の分を渡す
    int roundedMinute = (tempTime.minute ~/ 15) * 15;
    DateTime initialDateTime = DateTime(
      2024,
      1,
      1,
      tempTime.hour,
      roundedMinute,
    );
    tempTime = TimeOfDay(hour: tempTime.hour, minute: roundedMinute);

    showCupertinoModalPopup(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 260,
          color: Colors.white,
          child: Column(
            children: [
              // 決定ボタンバー
              Container(
                color: Colors.grey[200],
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CupertinoButton(
                      child: const Text('決定'),
                      onPressed: () {
                        setModalState(() {
                          if (isStart) {
                            startTime = tempTime;
                          } else {
                            endTime = tempTime;
                          }
                        });
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
              ),
              // スクロール式ピッカー本体
              Expanded(
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true, // 24時間表記
                  minuteInterval: 15, // 💡 ここで15分刻みに設定
                  initialDateTime: initialDateTime,
                  onDateTimeChanged: (DateTime newDateTime) {
                    tempTime = TimeOfDay(
                      hour: newDateTime.hour,
                      minute: newDateTime.minute,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  //365日後までの赤字になる日付をリストアップする関数
  Set<String> getShortageDays() {
    Set<String> shortageDays = {};
    int tempBalance = balance; // 今の所持金からスタート
    DateTime today = DateTime.now();

    for (int i = 0; i <= 365; i++) {
      DateTime targetDate = today.add(Duration(days: i));

      //その日の支出を引く
      for (var expense in expenses) {
        if (expense.date.year == targetDate.year &&
            expense.date.month == targetDate.month &&
            expense.date.day == targetDate.day) {
          tempBalance -= expense.amount;
        }
      }
      //その日がサブスクの引き落とし日なら自動で引く
      for (var sub in subscriptions) {
        if (targetDate.day == sub.billingDay) {
          tempBalance -= sub.amount;
        }
      }

      //その日の給料を足す（給料日の計算）
      for (var record in records) {
        try {
          Job job = myjobs.firstWhere((j) => j.name == record.jobName);
          DateTime payDayDate = calulatePayDay(record.date, job);
          if (payDayDate.year == targetDate.year &&
              payDayDate.month == targetDate.month &&
              payDayDate.day == targetDate.day) {
            tempBalance += record.amount;
          }
        } catch (e) {
          // 仕事が削除されていた場合は無視
        }
      }

      //マイナスなら赤字リストに追加
      if (tempBalance < 0) {
        shortageDays.add(
          '${targetDate.year}-${targetDate.month}-${targetDate.day}',
        );
      }
    }
    return shortageDays;
  }

  // 画面のリスト（2タブ）
  @override
  Widget build(BuildContext context) {
    final Set<String> redFlagDays = getShortageDays();
    Map<String, int> paydayAmounts = {}; //足し算用のマップ
    //shiftRecordのrecordsからrecordを繰り返して同じ名前のものを探す
    for (ShiftRecord record in records) {
      Job? targetJob;
      for (Job j in myjobs) {
        if (j.name == record.jobName) {
          targetJob = j;
          break;
        }
      }
      if (targetJob != null) {
        DateTime payDayDate = calulatePayDay(record.date, targetJob);
        String key = '${payDayDate.year}-${payDayDate.month}-${payDayDate.day}';
        if (paydayAmounts.containsKey(key)) {
          //マップに追加
          paydayAmounts[key] = paydayAmounts[key]! + record.amount;
        } else {
          paydayAmounts[key] = record.amount;
        }
      }
    }
    //支出用のマップ
    Map<String, int> expenseAmounts = {};
    for (ExpenseRecord e in expenses) {
      String key = '${e.date.year}-${e.date.month}-${e.date.day}';
      if (expenseAmounts.containsKey(key)) {
        expenseAmounts[key] = expenseAmounts[key]! + e.amount;
      } else {
        expenseAmounts[key] = e.amount;
      }
    }

    List<Widget> screens = <Widget>[
      // 1つ目のタブ：カレンダー画面
      Column(
        mainAxisAlignment: MainAxisAlignment.center, // 縦の中央寄せ
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2025, 1, 1), // カレンダーの始まりの日
            lastDay: DateTime.utc(2030, 12, 31), // カレンダーの終わりの日
            focusedDay: _focusedDay, // 現在フォーカスしている日
            holidayPredicate: (date) {
              String key = '${date.year}-${date.month}-${date.day}';
              return redFlagDays.contains(key);
            },
            calendarStyle: const CalendarStyle(
              holidayTextStyle: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            //入金のカレンダーでの表示
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                String key = '${date.year}-${date.month}-${date.day}';
                if (paydayAmounts.containsKey(key)) {
                  int? amount = paydayAmounts[key];
                  return Text(
                    '💰$amount',
                    style: const TextStyle(fontSize: 10, color: Colors.blue),
                  );
                } else {
                  return null;
                }
              },
            ),
            // どの日が選択されているかを判定する処理
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },

            // 日付がタップされたときの処理
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay; // ページが切り替わってもフォーカスを合わせるため
              });
            },
          ),
          SizedBox(height: 20), // 20ピクセルの隙
          //選択された日の仕事予定の表示
          Expanded(
            child: Builder(
              builder: (context) {
                final selectedRecords = records.where((record) {
                  return isSameDay(record.date, _selectedDay);
                }).toList();
                final selectedExpenses = expenses.where((expense) {
                  return isSameDay(expense.date, _selectedDay);
                }).toList();
                return ListView.builder(
                  itemCount: selectedRecords.length + selectedExpenses.length,
                  itemBuilder: (context, index) {
                    if (index < selectedRecords.length) {
                      final record = selectedRecords[index];
                      return Dismissible(
                        key: Key(record.hashCode.toString()),
                        onDismissed: (direction) async {
                          setState(() {
                            records.remove(record);
                          });
                          await _saveRecords();
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),

                        child: Card(
                          child: ListTile(
                            leading: const Icon(Icons.work),
                            title: Text(record.jobName),
                            trailing: Text('${record.amount}円'),
                          ),
                        ),
                      );
                    } else {
                      // 💡 ここが腕の見せ所：支出リスト用のindexを計算し直す
                      final expenseIndex = index - selectedRecords.length;
                      final expense = selectedExpenses[expenseIndex];

                      return Dismissible(
                        key: Key(expense.hashCode.toString()),
                        onDismissed: (direction) async {
                          setState(() {
                            expenses.remove(expense);
                          });
                          await _saveExpenses();
                        },
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16.0),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.shopping_cart,
                              color: Colors.red,
                            ),
                            title: Text(expense.title),
                            trailing: Text(
                              '-${expense.amount}円',
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
        ],
      ),

      // 2つ目のタブ：収支・目標画面
      Column(
        mainAxisAlignment: MainAxisAlignment.center, // 縦の中央寄せ
        children: [
          // 2つ目のタブ：収支・目標画面 の Column の children の先頭あたりに追加
          Card(
            elevation: 4,
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右に離して配置
                children: [
                  Text(
                    '現在の所持金: ¥$balance',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('所持金の更新'),
                          content: TextField(
                            controller: balanceController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: '実際の残高を入力',
                            ),
                          ),
                          actions: [
                            ElevatedButton(
                              onPressed: () async {
                                setState(() {
                                  // 入力された文字を数字(int)に変換して currentBalance を上書き
                                  balance = int.parse(balanceController.text);
                                });
                                final prefs =
                                    await SharedPreferences.getInstance();
                                await prefs.setInt('my_balance', balance);
                                balanceController.clear();
                                Navigator.pop(context); // ダイアログを閉じる
                              },
                              child: const Text('更新する'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          Card(
            elevation: 4, // 影の濃さ（4くらい）
            margin: const EdgeInsets.all(16), // カードの外側の隙間
            child: Padding(
              padding: const EdgeInsets.all(16), // カードの内側の隙間
              child: Column(
                children: [
                  Text(
                    '${maxEarning ~/ 10000}万の壁（扶養枠）まであと',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '¥ ${maxEarning - calculation()}', //残金表示計算
                    style: TextStyle(
                      fontSize: 24,
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 進捗ゲージ本体value: 0.0 〜 1.0 で割合を指定
                  LinearProgressIndicator(
                    value: calculation() / maxEarning,
                    minHeight: 10,
                    backgroundColor: Colors.grey[300], // ゲージの背景色
                    color: Colors.blueAccent, // ゲージの中身の色
                  ),

                  const SizedBox(height: 8),
                  Text(
                    '現在の累計収入: ¥ ${calculation()} / ¥ $maxEarning',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 20), // 20ピクセルの隙間
          // 画面に追加された金額等の表示
          Expanded(
            child: ListView.builder(
              itemCount: expenses.length,
              itemBuilder: (context, index) {
                return Dismissible(
                  // データの固有IDをキーにする
                  key: Key(expenses[index].hashCode.toString()),

                  onDismissed: (direction) async {
                    setState(() {
                      expenses.removeAt(index);
                    });
                    await _saveExpenses();
                  },

                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16.0),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),

                  // 今までのCardをそのままchildに入れる
                  child: Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.shopping_cart,
                        color: Colors.red,
                      ),
                      title: Text(expenses[index].title),
                      subtitle: Text(
                        '${expenses[index].date.month}月${expenses[index].date.day}日',
                      ),
                      trailing: Text(
                        '${expenses[index].amount}円',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.red,
                        ),
                      ),
                      //勤務時間が実際にずれた時の処理
                      onTap: () {
                        double adjustmentMinutes = 0.0;

                        showDialog(
                          context: context,
                          builder: (BuildContext context) {
                            return StatefulBuilder(
                              builder:
                                  (
                                    BuildContext context,
                                    StateSetter setModalState,
                                  ) {
                                    return AlertDialog(
                                      title: const Text('勤怠修正'),
                                      content: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Slider(
                                              value: adjustmentMinutes,
                                              min: -120,
                                              max: 120,
                                              divisions: 16,
                                              label:
                                                  '${adjustmentMinutes.toInt()}分',
                                              onChanged: (double newValue) {
                                                setModalState(() {
                                                  adjustmentMinutes = newValue;
                                                });
                                              },
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                int targetWage = 0;
                                                for (Job j in myjobs) {
                                                  if (j.name ==
                                                      records[index].jobName) {
                                                    targetWage = j.hourlyWage;
                                                  }
                                                }
                                                int diffValue =
                                                    ((targetWage / 60) *
                                                            adjustmentMinutes)
                                                        .toInt();
                                                setState(() {
                                                  records[index].amount +=
                                                      diffValue;
                                                });
                                                Navigator.pop(context);
                                              },
                                              child: const Text('保存する'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                            );
                          },
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('収支・キャッシュフロー管理'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // 新しい仕事の追加作成
          IconButton(
            icon: const Icon(Icons.add_business),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('新しい仕事の登録'),
                  content: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          keyboardType: TextInputType.name,
                          controller: newJobNameController,
                          decoration: const InputDecoration(labelText: '仕事名'),
                        ),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: newJobWageController,
                          decoration: const InputDecoration(labelText: '時給'),
                        ),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: newJobClosingDayController,
                          decoration: const InputDecoration(labelText: '締め日'),
                        ),
                        TextField(
                          keyboardType: TextInputType.number,
                          controller: newJobPayDayController,
                          decoration: const InputDecoration(labelText: '給料日'),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              myjobs.add(
                                Job(
                                  name: newJobNameController.text,
                                  hourlyWage: int.parse(
                                    newJobWageController.text,
                                  ),
                                  closingDay:
                                      int.tryParse(
                                        newJobClosingDayController.text,
                                      ) ??
                                      25,
                                  payDay:
                                      int.tryParse(
                                        newJobPayDayController.text,
                                      ) ??
                                      26,
                                  color: Colors.blue,
                                ),
                              );
                            });
                            //myjobsリストの中身をすべてtoJsonで解体し、文字列に圧縮
                            String jsonString = jsonEncode(
                              myjobs.map((job) => job.toJson()).toList(),
                            );

                            //書き込み
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.setString('my_jobs_key', jsonString);

                            newJobNameController.clear();
                            newJobWageController.clear();
                            newJobClosingDayController.clear();
                            newJobPayDayController.clear();
                            debugPrint('登録リスト数:${myjobs.length}');
                            Navigator.pop(context);
                          },
                          child: const Text('追加する'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          //支出の新規登録
          IconButton(
            icon: const Icon(Icons.money_off),
            onPressed: () {
              DateTime tempDate = DateTime.now(); // ダイアログ内でのみ使う日付変数
              showDialog(
                context: context,
                builder: (context) => StatefulBuilder(
                  // StatefulBuilderを使うことで、ダイアログを開いたまま日付表示だけを更新
                  builder: (context, setDialogState) {
                    return AlertDialog(
                      title: const Text('支出の登録'),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextField(
                            controller: expenseTitleController,
                            decoration: const InputDecoration(
                              labelText: '支出名目',
                            ),
                          ),
                          TextField(
                            controller: expenseAmountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '金額'),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: tempDate,
                                firstDate: DateTime(2023),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setDialogState(() {
                                  tempDate = picked; // 選んだ日付で上書きして画面更新
                                });
                              }
                            },
                            child: Text(
                              '${tempDate.month}月${tempDate.day}日に支出',
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () async {
                            setState(() {
                              // 入力された文字を型変換して、expensesリストに追加
                              expenses.add(
                                ExpenseRecord(
                                  title: expenseTitleController.text,
                                  amount: int.parse(
                                    expenseAmountController.text,
                                  ),
                                  date: tempDate,
                                ),
                              );
                            });
                            // 次回開いたときのために空に
                            expenseTitleController.clear();
                            expenseAmountController.clear();
                            await _saveExpenses();
                            Navigator.pop(context);
                          },
                          child: const Text('追加する'),
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),

          //サブスクの登録ボタン
          IconButton(
            icon: const Icon(Icons.autorenew),
            onPressed: () {
              TextEditingController subTitleController =
                  TextEditingController();
              TextEditingController subAmountController =
                  TextEditingController();
              TextEditingController subDayController = TextEditingController();

              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('サブスク・固定費の登録'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: subTitleController,
                        decoration: const InputDecoration(
                          labelText: '項目名 (例: Netflix)',
                        ),
                      ),
                      TextField(
                        controller: subAmountController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: '毎月の金額'),
                      ),
                      TextField(
                        controller: subDayController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: '毎月の引き落とし日 (日)',
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () async {
                        setState(() {
                          subscriptions.add(
                            Subscription(
                              title: subTitleController.text,
                              amount: int.parse(subAmountController.text),
                              billingDay: int.parse(subDayController.text),
                            ),
                          );
                        });
                        await _saveSubscriptions();
                        Navigator.pop(context);
                      },
                      child: const Text('登録'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: screens[_selectedIndex], // ここで上のListから画面を選んで表示
      // 金額等の追加作成
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context, //今アプリのどの画面にいるのかの位置情報
            builder: (BuildContext context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setModalState) {
                  //表示したいwidgetを返させる
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        DropdownButton<Job>(
                          hint: const Text('仕事を選択'),
                          value: selectedJob,
                          items: myjobs.map((Job job) {
                            return DropdownMenuItem<Job>(
                              value: job,
                              child: Text(job.name),
                            );
                          }).toList(),
                          onChanged: (Job? newValue) {
                            setModalState(() {
                              selectedJob = newValue;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        //開始時間のボタン
                        ElevatedButton(
                          onPressed: () => _showSpinnerTimePicker(
                            context,
                            setModalState,
                            true,
                          ),
                          child: Text(
                            startTime == null
                                ? '開始時間'
                                : '開始: ${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
                          ),
                        ),

                        const SizedBox(height: 8),

                        //終了時間のボタン
                        ElevatedButton(
                          onPressed: () => _showSpinnerTimePicker(
                            context,
                            setModalState,
                            false,
                          ),
                          child: Text(
                            endTime == null
                                ? '終了時間'
                                : '終了: ${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
                          ),
                        ),

                        ElevatedButton(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2023),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null && picked != selectedDate) {
                              setState(() {
                                selectedDate = picked;
                              });
                            }
                          },
                          child: Text(
                            '${selectedDate.month}月${selectedDate.day}日のシフト',
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (selectedJob == null ||
                                startTime == null ||
                                endTime == null) {
                              return;
                            }
                            setState(() {
                              records.add(
                                ShiftRecord(
                                  amount: salaryCalculation(
                                    startTime!,
                                    endTime!,
                                    selectedJob!,
                                  ),
                                  date: selectedDate,
                                  jobName: selectedJob!.name,
                                ),
                              );
                              selectedJob = null;
                              startTime = null;
                              endTime = null;
                              selectedDate = DateTime.now();
                            });
                            await _saveRecords();
                            Navigator.pop(context); //閉じる
                            controller.clear();
                            jobcontroller.clear();
                            debugPrint('金額リスト:$records');
                          },
                          child: Text('追加する'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
        child: const Icon(Icons.add), // 追加ボタンの作成
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index; // タブが押されたら画面を切り替える
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'カレンダー',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: '収支・目標',
          ),
        ],
      ),
    );
  }
}

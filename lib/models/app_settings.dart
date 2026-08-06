class AppSettings {
  const AppSettings({
    this.initialMileage,
    required this.standardTripPrice,
    required this.hourlyOrderRate,
    required this.intercityOrderRate,
    required this.defaultFuelPrice,
    required this.summerConsumption,
    required this.winterConsumption,
    required this.tankVolume,
    required this.orderReminderHours,
    required this.workFundPercent,
    required this.loanFundPercent,
    required this.personalFundPercent,
  });

  /// Первый известный пробег автобуса.
  final int? initialMileage;

  /// Цена утреннего и вечернего рейса предприятия.
  final double standardTripPrice;

  /// Стоимость одного часа заказа.
  final double hourlyOrderRate;

  /// Стоимость одного километра межгорода.
  final double intercityOrderRate;

  /// Цена топлива, которая будет подставляться в форму заправки.
  final double defaultFuelPrice;

  /// Средний летний расход на 100 км.
  final double summerConsumption;

  /// Средний зимний расход на 100 км.
  final double winterConsumption;

  /// Объём топливного бака.
  final double tankVolume;

  /// За сколько часов напоминать о заказе.
  final int orderReminderHours;

  /// Процент рабочего фонда.
  final double workFundPercent;

  /// Процент кредитного фонда.
  final double loanFundPercent;

  /// Процент личных денег.
  final double personalFundPercent;

  double get totalFundPercent {
    return workFundPercent +
        loanFundPercent +
        personalFundPercent;
  }

  bool get hasValidFundPercent {
    return (totalFundPercent - 100).abs() < 0.001;
  }

  AppSettings copyWith({
    int? initialMileage,
    bool clearInitialMileage = false,
    double? standardTripPrice,
    double? hourlyOrderRate,
    double? intercityOrderRate,
    double? defaultFuelPrice,
    double? summerConsumption,
    double? winterConsumption,
    double? tankVolume,
    int? orderReminderHours,
    double? workFundPercent,
    double? loanFundPercent,
    double? personalFundPercent,
  }) {
    return AppSettings(
      initialMileage: clearInitialMileage
          ? null
          : initialMileage ?? this.initialMileage,
      standardTripPrice:
      standardTripPrice ?? this.standardTripPrice,
      hourlyOrderRate:
      hourlyOrderRate ?? this.hourlyOrderRate,
      intercityOrderRate:
      intercityOrderRate ?? this.intercityOrderRate,
      defaultFuelPrice:
      defaultFuelPrice ?? this.defaultFuelPrice,
      summerConsumption:
      summerConsumption ?? this.summerConsumption,
      winterConsumption:
      winterConsumption ?? this.winterConsumption,
      tankVolume: tankVolume ?? this.tankVolume,
      orderReminderHours:
      orderReminderHours ?? this.orderReminderHours,
      workFundPercent:
      workFundPercent ?? this.workFundPercent,
      loanFundPercent:
      loanFundPercent ?? this.loanFundPercent,
      personalFundPercent:
      personalFundPercent ?? this.personalFundPercent,
    );
  }

  factory AppSettings.defaults() {
    return const AppSettings(
      initialMileage: null,
      standardTripPrice: 2700,
      hourlyOrderRate: 2000,
      intercityOrderRate: 55,
      defaultFuelPrice: 0,
      summerConsumption: 11.5,
      winterConsumption: 13.2,
      tankVolume: 80,
      orderReminderHours: 12,
      workFundPercent: 30,
      loanFundPercent: 35,
      personalFundPercent: 35,
    );
  }
}
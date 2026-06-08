class GameTimeConfig {
  const GameTimeConfig._();

  // 수정53차: MMORPG식 게임 시간 기준
  // 현실 1초 = 게임 1분
  // 현실 1분 = 게임 1시간
  static const int realSecondsPerGameMinute = 1;

  static const int gameMinutesPerHour = 60;
  static const int gameHoursPerDay = 24;
  static const int gameMinutesPerDay = gameMinutesPerHour * gameHoursPerDay;
  static const int gameDaysPerWeek = 7;
  static const int gameMinutesPerWeek = gameMinutesPerDay * gameDaysPerWeek;

  // 수정53차: 시장별 게임 시간 기준 변동 주기
  // 코인: 게임 시간 10분마다 변동
  // 주식: 게임 시간 1시간마다 변동
  // 부동산: 게임 시간 1일 또는 1주 단위 변동
  static const int coinMarketTickGameMinutes = 10;
  static const int stockMarketTickGameMinutes = gameMinutesPerHour;
  static const int realEstateDailyTickGameMinutes = gameMinutesPerDay;
  static const int realEstateWeeklyTickGameMinutes = gameMinutesPerWeek;
}
class Game
  property id : String
  property last_checked_at : Time

  def initialize(@id : String, @last_checked_at=Time.now)
  end
end

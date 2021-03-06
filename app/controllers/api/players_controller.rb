class Api::PlayersController < ApplicationController
  before_filter :find_league
  respond_to :json
  def index
    limit = params[:count] || 100
    @players = Player.limit(limit)
    respond_with(@players)
  end

  def available
    limit = params[:count] || 10
    name = params[:name]
    position = params[:position]

    #get the rest of them
    player_scope = Player.available_for_league(params[:league_id]).limit(limit)

    if name
      player_scope = player_scope.where("(LOWER(players.name) LIKE ?)", "%#{name.downcase}%")
    end

    if !position.blank?
      player_scope = player_scope.where("players.position = ?", position)
    end

    respond_with player_scope
  end

  def drafted
    @team = Team.find(params[:team_id])
    render json: @team.players
  end

  def find_league
    league_id = params[:league_id]
    if league_id
      @league = League.find(league_id)
    end
  end

  def draft
    @team = Team.find(params[:team_id])
    @player = Player.find(params[:player_id])
    @draftPick = @league.current_pick

    if @league.pause
      render json: "The draft is not active", status: :unprocessable_entity
      return
    end

    #make sure this is the current pick
    if(@draftPick.team_id == @team.id && @league.player_available(@player.id))
      @draftPick.player_id = @player.id
      @draftPick.missed = false

      #determine ADPD
      # ADPD = ceil ((ADP - pick_number) / 10)
      pick_number = (((@draftPick.round-1)*@league.teams.count) + @draftPick.pick)
      @draftPick.adpd = ((@player.adp - pick_number) / 10).ceil

      if @draftPick.save
        if DraftPick.where("league_id = ? AND player_id is NULL", @league.id).count > 0
          @league.move_to_the_next_pick
          next_pick = @league.current_pick
          next_pick.timestamp = Time.now + 2.seconds
          next_pick.save
          @league.save
          Pusher['draft'].trigger('pick_made', draft_info_json(@league.id, @draftPick))
          render json: @draftPick
        else
          #THE DRAFT IS OVER!!
          @league.pause = true
          @league.save
          Pusher['draft'].trigger("end_draft", draft_info_json(@league.id, @draftPick))
          render :nothing => true, :status => 200, :content_type => 'text/html'
        end
      else
        render json: @draftPick.errors, status: :unprocessable_entity
      end
    else
      render json: "Something Went Wrong!", status: :unprocessable_entity
    end
  end

  def draft_info_json(league_id, draftPick)
    @league = League.find(league_id)
    @current_pick = @league.current_pick
    @upcoming_picks = DraftPick.where("league_id = ? AND player_id is NULL AND id != ?", league_id, @current_pick.id).limit(9).order("round desc, pick desc")
    @available_players = Player.available_for_league(league_id).limit(10)
    @rosters = Team.where(league_id: league_id).order(:pick)
    @team = @draftPick.team
    {league: @league.to_json, currentPick: @current_pick.to_json(:include => {:team => {:include => {:draftPicks => {:include => :player}}}}), futurePicks: @upcoming_picks.to_json(:include => :team), availablePlayers: @available_players.to_json, rosters: @rosters.to_json(:include => {:draftPicks => {:include => :player }}), team: @team.to_json(:include => {:draftPicks => {:include => :player}}), draftPick: @draftPick.to_json(:include => [:player, :team])}
  end
end

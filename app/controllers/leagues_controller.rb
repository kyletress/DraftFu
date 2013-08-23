class LeaguesController < ApplicationController
  # before_filter :validate_commissioner

  def validate_commissioner
    league = League.find(params[:id])
    if !league.nil?
      if current_user.id != league.commissioner_id
        redirect_to root_url, :alert => "First login to access this page."
      end
    end
  end
  
  def index
    @leagues = current_user.leagues
  end

  def new
    @league = League.new
  end
  
  def create
    @league = League.new(params[:league])
    @league.commissioner = current_user
    if @league.save
      redirect_to leagues_url, notice: 'League was successfully created.'
    else
      render action: "new"
    end
  end

  def edit
    @league = League.find(params[:id])
  end
  
  def update
    @league = League.find(params[:id])
    
    if @league.update_attributes(params[:league])
      redirect_to leagues_url, notice: 'League was successfully updated.'      
    else
      render :edit
    end
  end
  
  def show
    @league = League.find(params[:id])
  end

  def draft
    @league = League.find(params[:id])
    @current_pick = @league.current_pick
  end

  def draftboard
    @league = League.find(params[:id])
    @current_pick = @league.current_pick
    @rosters = Team.where(league_id: params[:id]).order(:pick) 
    @upcoming_picks = DraftPick.where("league_id = ? AND player_id is NULL AND id != ?", params[:id], @current_pick.id).limit(9).order("round desc, pick desc")
  end

  def team_draft
    @league = League.find(params[:id])
    @current_pick = @league.current_pick
    @upcoming_picks = DraftPick.where("league_id = ? AND player_id is NULL AND id != ?", params[:id], @current_pick.id).limit(9).order("round desc, pick desc")
    @available_players = Player.available_for_league(params[:id]).limit(10)
    @rosters = Team.where(league_id: params[:id]).order(:pick) 
  end
end

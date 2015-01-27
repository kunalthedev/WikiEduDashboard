class Revision < ActiveRecord::Base
  belongs_to :user
  belongs_to :article



  ####################
  # Instance methods #
  ####################
  def update(data={}, save=true)
    self.attributes = data

    if save
      self.save
    end
  end



  #################
  # Class methods #
  #################
  def self.update_all_revisions
    data = Figaro.env.cohorts.split(",").reduce([]) do |result, cohort|
      users = User.student.includes(:courses).where(:courses => {:cohort => cohort})
      revisions = Utils.chunk_requests(users, 40) { |block|
        cohort_start = ENV["cohort_" + cohort + "_start"]
        cohort_end = ENV["cohort_" + cohort + "_end"]
        Replica.get_revisions_this_term_by_users block, cohort_start, cohort_end
      }
      result += revisions
    end
    # if(Revision.count == 0)
    self.import_revisions(data)
    # else
    #   data.each do |a_id, a|
    #     article = Article.find_or_create_by(id: a["article"]["id"])
    #     article.update a["article"]
    #     a["revisions"].each do |r|
    #       revision = Revision.find_or_create_by(id: r["id"])
    #       revision.update r
    #     end
    #   end
    # end

    ActiveRecord::Base.transaction do
      Revision.joins(:article).where(articles: {namespace: "0"}).each do |r|
        r.user.courses.each do |c|
          if((!c.articles.include? r.article) && (c.start <= r.date))
            c.articles << r.article
          end
        end
      end
    end
  end

  def self.import_revisions(data)
    articles = []
    revisions = []

    data.each do |a_id, a|
      article = Article.new(id: a["article"]["id"])
      article.update(a["article"], false)
      #article["revision_count"] = a["revisions"].count
      articles.push article

      a["revisions"].each do |r|
        revision = Revision.new(id: r["id"])
        revision.update(r, false)
        revisions.push revision
      end
    end

    Article.import articles
    Revision.import revisions

  end


end
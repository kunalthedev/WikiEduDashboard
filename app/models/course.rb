class Course < ActiveRecord::Base
  has_many :courses_users, class_name: CoursesUsers

  has_many :users, -> { uniq }, through: :courses_users
  has_many :revisions, -> (course) { where("date >= ?", course.start) }, through: :users

  has_many :articles_courses, class_name: ArticlesCourses
  has_many :articles, -> { uniq }, through: :articles_courses

  # has_many :assignments
  # has_many :assigned_articles, -> { uniq }, through: :assignments, :class_name => "Article"

  scope :cohort, -> (cohort) { where cohort: cohort }


  ####################
  # Instance methods #
  ####################
  def to_param
    self.slug
  end


  def update(data={}, save=true)
    if data.blank?
      data = Wiki.get_course_info self.id
    end
    self.attributes = data["course"]
    if save
      data["participants"].each_with_index do |(r, p), i|
        User.add_users(data["participants"][r], i, self)
      end
      self.save
    end
  end



  #################
  # Cache methods #
  #################
  def character_sum
    if(!read_attribute(:character_sum))
      update_cache()
    end
    read_attribute(:character_sum)
  end


  def view_sum
    if(!read_attribute(:view_sum))
      update_cache()
    end
    read_attribute(:view_sum)
  end


  def user_count
    read_attribute(:user_count) || users.student.size
  end


  def revision_count
    read_attribute(:revision_count) || revisions.size
  end


  def article_count
    read_attribute(:article_count) || articles.size
  end


  def update_cache
    # Do not consider revisions with negative byte changes
    self.character_sum = courses_users.sum(:character_sum_ms)
    self.view_sum = articles_courses.sum(:view_count)
    self.user_count = users.student.size
    self.revision_count = revisions.size
    self.article_count = articles.size
    self.save
  end



  #################
  # Class methods #
  #################
  def self.update_all_courses(initial=false)
    raw_ids = Wiki.get_course_list
    listed_ids = raw_ids.values.flatten
    course_ids = listed_ids | Course.all.pluck(:id).map(&:to_s)
    minimum = course_ids.map(&:to_i).min
    maximum = course_ids.map(&:to_i).max
    max_plus = maximum + 2
    if(initial)
      course_ids = (0..max_plus).to_a.map(&:to_s)
    else
      course_ids = course_ids | (maximum..max_plus).to_a.map(&:to_s)
    end

    data = Utils.chunk_requests(course_ids) {|c| Wiki.get_course_info c}
    # if(Course.count == 0)
    self.import_courses(raw_ids, data)
    # else
    #   data.each do |c|
    #     if listed_ids.include?(c["course"]["id"])
    #       c["course"]["listed"] = true
    #       c["course"]["cohort"] = raw_ids.reduce(nil) do |out, (cohort, cohort_courses)|
    #         out = cohort_courses.include?(c["course"]["id"]) ? cohort : out
    #       end
    #     end
    #     course = Course.find_or_create_by(id: c["course"]["id"])
    #     course.update c
    #   end
    # end
  end

  def self.import_courses(raw_ids, data)
    courses = []
    participants = {}
    listed_ids = raw_ids.values.flatten
    data.each do |c|
      if listed_ids.include?(c["course"]["id"])
        c["course"]["listed"] = true
        c["course"]["cohort"] = raw_ids.reduce(nil) do |out, (cohort, cohort_courses)|
          out = cohort_courses.include?(c["course"]["id"]) ? cohort : out
        end
      else
        c["course"]["listed"] = false
        c["course"]["cohort"] = nil
      end
      course = Course.new(id: c["course"]["id"])
      course.update(c, false)
      courses.push course
      participants[c["course"]["id"]] = c["participants"]
    end
    Course.import courses, :on_duplicate_key_update => [:start, :end, :listed, :cohort]

    users = []
    participants.each do |course_id, groups|
      groups.each_with_index do |(r, p), i|
        users = User.add_users(groups[r], i, nil, false) | users
      end
    end
    User.import users

    ActiveRecord::Base.transaction do
      participants.each do |course_id, group|
        user_ids = group.map{|g,gusers| gusers.empty? ? nil : gusers}.compact.flatten.map{|user| user["id"]}
        Course.find_by(id: course_id).users << User.find(user_ids)
      end
    end
  end

  def self.update_all_caches
    Course.transaction do
      Course.all.each do |c|
        c.update_cache
      end
    end
  end


end

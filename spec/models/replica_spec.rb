require 'rails_helper'

describe Replica do
  describe 'API requests' do
    it 'should connect to replica tools' do
      response = Replica.connect_to_tool
      # rubocop:disable Metrics/LineLength
      expect(response).to eq('You have successfully reached to the WikiEduDashboard tool hosted by the Wikimedia Tool Labs.')
      # rubocop:enable Metrics/LineLength
    end

    # rubocop:disable Style/NumericLiterals
    it 'should return revisions from this term' do
      VCR.use_cassette 'replica/revisions' do
        all_users = [
          { 'wiki_id' => 'ELE427' },
          { 'wiki_id' => 'Ragesoss' },
          { 'wiki_id' => 'Mrbauer1234' }
        ]
        rev_start = 2014_01_01_003430
        rev_end = 2014_12_31_003430

        all_users.each_with_index do |u, i|
          all_users[i] = OpenStruct.new u
        end
        response = Replica.get_revisions(all_users, rev_start, rev_end)

        # This count represents the number of articles and userpages
        # edited by the users, not the number of revisions. Revisions are child
        # elements of the page ids.
        expect(response.count).to eq(139)

        # Make sure we handle the case of zero revisions.
        rev_start = 2015_01_05
        rev_end = 2015_01_06
        response = Replica.get_revisions(all_users, rev_start, rev_end)
        expect(response.count).to eq(0)

        # Make sure we handle the case of one revision.
        rev_start = 2015_01_05
        rev_end = 2015_01_08
        response = Replica.get_revisions(all_users, rev_start, rev_end)
        expect(response.count).to eq(1)
      end
    end
    # rubocop:enable Style/NumericLiterals

    it 'should return a list of users who completed training' do
      VCR.use_cassette 'replica/training' do
        all_users = [
          { 'wiki_id' => 'ELE427' }, # has not completed
          { 'wiki_id' => 'Ragesoss' }, # has completed
          { 'wiki_id' => 'Mrbauer1234' }, # has not completed
          { 'wiki_id' => 'Ragesock' }, # has completed
          { 'wiki_id' => 'Sage (Wiki Ed)' } # has completed
        ]
        all_users.each_with_index do |u, i|
          all_users[i] = OpenStruct.new u
        end
        response = Replica.get_users_completed_training(all_users)
        expect(response.count).to eq(3)
      end
    end

    it 'should return a list of existing articles' do
      VCR.use_cassette 'replica/articles' do
        article_titles = [
          { 'title' => 'Autism' }, # exists
          { 'title' => 'Allegiance' }, # exists
          { 'title' => 'Paul_Cézanne' }, # exists (with special characters)
          { 'title' => 'Mmilldev/sandbox' } # does not exist
        ]
        response = Replica.get_existing_articles(article_titles)
        expect(response.size).to eq(3)
      end
    end

    it 'should function identically on non-English wikis' do
      VCR.use_cassette 'replica/es_revisions' do
        allow(Figaro.env).to receive(:wiki_language).and_return('es')
        all_users = [
          { 'wiki_id' => 'AndresAlvarezGalina95' },
          { 'wiki_id' => 'Patyelena25' },
          { 'wiki_id' => 'Lizmich91' }
        ]
        # rubocop:disable Style/NumericLiterals
        rev_start = 2015_02_12_003430
        rev_end = 2015_03_10_003430
        # rubocop:enable Style/NumericLiterals

        all_users.each_with_index do |u, i|
          all_users[i] = OpenStruct.new u
        end
        response = Replica.get_revisions(all_users, rev_start, rev_end)
        expect(response.count).to eq(20)
      end
    end
  end
end

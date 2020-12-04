class HerokuLogsAnalyser
  def initialize(file_path)
    @heroku_logs = File.readlines(file_path)
  end
  
  def analysis
    result = Array.new
    logs_info = logs_collection      
    logs_info.group_by{|h| h[:identifier] }.each do |key, value|
      called = value.collect { |hs| hs[:identifier] }.size

      response_time = value.collect { |hs| hs[:response_time] }
      
      dynos = value.collect { |hs| hs[:dyno_mode] }
      freq = dynos.inject(Hash.new(0)) { |h, x| h[x] += 1; h }
      dyno = freq.max_by { |x| freq[x] }.first

      result << {
        request_identifier: key,
        called: called,
        response_time_mean: mean(response_time),
        response_time_mode: modes(response_time),
        response_time_median: median(response_time),
        dyno_mode: dyno
      }
    end
    result  
  end

  private

    def logs_collection
      logs_info = Array.new  
      @heroku_logs.each do |line|
        http_verb = line[/method=([^\s]+)/, 1]
        path      = line[/path=([^\s]+)/, 1]
        dyno      = line[/dyno=([^\s]+)/, 1]
        service   = line[/service=([^\s]+)/, 1].to_i
        connect   = line[/connect=([^\s]+)/, 1].to_i
    
        response_time = service + connect
        uri = "#{http_verb} #{path.gsub(/\d+/, '{resource_id}')}"
    
        logs_info << {
          identifier: uri,
          response_time: response_time,
          dyno_mode: dyno
        }
      end
      logs_info      
    end
    

    def mean(array)
      array = array.inject(0) { |sum, x| sum += x } / array.size.to_f
    end

    def median(array, already_sorted=false)
      return nil if array.empty?
      array = array.sort unless already_sorted
      m_pos = array.size / 2
      return array.size % 2 == 1 ? array[m_pos] : mean(array[m_pos-1..m_pos])
    end

    def modes(array, find_all=true)
      hs = array.inject(Hash.new(0)) { |h, n| h[n] += 1; h }
      modes = nil
      hs.each_pair do |item, times|
        modes << item if modes && times == modes[0] and find_all
        modes = [times, item] if (!modes && times>1) or (modes && times>modes[0])
      end
      return modes ? modes[1...modes.size] : modes
    end
end

logs = HerokuLogsAnalyser.new('sample.log')
p logs.analysis
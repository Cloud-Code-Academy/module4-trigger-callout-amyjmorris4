/**
 * Wrapper class for parsing the NewsAPI response (see https://newsapi.org/docs/endpoints/top-headlines)
 */
public class NewsAPIResponse {
    public String status { get; set; }
    public Integer totalResults { get; set; }
    /** Present when status is "error" */
    public String code { get; set; }
    /** Present when status is "error" */
    public String message { get; set; }
    public List<Article> articles { get; set; }

    /**
     * Inner class representing a news article from the API JSON
     */
    public class Article {
        public Source source { get; set; }
        public String author { get; set; }
        public String title { get; set; }
        public String description { get; set; }
        public String url { get; set; }
        public String urlToImage { get; set; }
        public String publishedAt { get; set; }
        public String content { get; set; }
    }

    /**
     * Inner class representing the article's source object in the API JSON
     */
    public class Source {
        public String id { get; set; }
        public String name { get; set; }
    }

    /**
     * Deserializes a JSON body from NewsAPI into a NewsAPIResponse instance.
     */
    public static NewsAPIResponse parse(String jsonBody) {
        return (NewsAPIResponse) JSON.deserialize(jsonBody, NewsAPIResponse.class);
    }

    /**
     * Converts an API article to an Article__c SObject.
     * Set Name, Category__c, and News_Category__c as needed in the caller (e.g. from the sync category).
     *
     * @param apiArticle The API article to convert
     * @return Article__c record populated from the API, or null if apiArticle is null
     */
    public static Article__c convertToSObject(Article apiArticle) {
        if (apiArticle == null) {
            return null;
        }

        Article__c record = new Article__c();
        record.Name = buildRecordName(apiArticle.title);
        record.Title__c = truncate(apiArticle.title, 255);
        record.Description__c = truncateLong(apiArticle.description, 32768);
        record.url__c = truncate(apiArticle.url, 255);
        record.urlToImage__c = truncate(apiArticle.urlToImage, 255);
        record.Published_At__c = parsePublishedAt(apiArticle.publishedAt);
        record.Source__c = apiArticle.source != null ? truncate(apiArticle.source.name, 255) : null;
        record.Author__c = truncate(apiArticle.author, 255);
        record.Content__c = truncateLong(apiArticle.content, 131072);
        return record;
    }

    private static String buildRecordName(String title) {
        String base = String.isNotBlank(title) ? title.trim() : 'Article';
        return base.length() > 80 ? base.substring(0, 80) : base;
    }

    private static String truncate(String value, Integer maxLen) {
        if (String.isBlank(value)) {
            return null;
        }
        String v = value.trim();
        return v.length() > maxLen ? v.substring(0, maxLen) : v;
    }

    private static String truncateLong(String value, Integer maxLen) {
        if (String.isBlank(value)) {
            return null;
        }
        return value.length() > maxLen ? value.substring(0, maxLen) : value;
    }

    private static Datetime parsePublishedAt(String publishedAt) {
        if (String.isBlank(publishedAt)) {
            return null;
        }
        String normalized = publishedAt.replace('T', ' ');
        if (normalized.contains('.')) {
            normalized = normalized.substringBefore('.');
        }
        normalized = normalized.replace('Z', '').trim();
        return Datetime.valueOfGmt(normalized);
    }
}

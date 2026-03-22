/**
 * Queueable Apex class for processing News Category records with pagination support
 */
public class NewsCategoryQueueable implements Queueable, Database.AllowsCallouts {
    private static final Integer MAX_PAGES = 3;
    /** Must stay aligned with {@link NewsAPIService} page size */
    private static final Integer API_PAGE_SIZE = 20;

    private News_Category__c category;
    private Integer currentPage;

    /**
     * Constructor
     * @param category The News_Category__c record
     * @param currentPage Current page to process
     */
    public NewsCategoryQueueable(News_Category__c category, Integer currentPage) {
        this.category = category;
        this.currentPage = (currentPage == null || currentPage < 1) ? 1 : currentPage;
    }

    /**
     * Execute method for the queueable job
     * @param context The QueueableContext
     */
    public void execute(QueueableContext context) {
        News_Category__c updatedCategory = new News_Category__c(Id = category.Id);

        try {
            NewsAPIResponse response = NewsAPIService.getTopHeadlinesByCategory(category.Name, currentPage);

            List<Article__c> toInsert = new List<Article__c>();
            if (response.articles != null) {
                for (NewsAPIResponse.Article apiArticle : response.articles) {
                    Article__c row = NewsAPIResponse.convertToSObject(apiArticle);
                    if (row != null) {
                        row.Category__c = category.Name;
                        row.News_Category__c = category.Id;
                        toInsert.add(row);
                    }
                }
            }
            if (!toInsert.isEmpty()) {
                insert toInsert;
            }

            Boolean chainNextPage = shouldEnqueueNextPage(response) && !Test.isRunningTest();
            if (chainNextPage) {
                News_Category__c nextCategory = new News_Category__c(
                    Id = category.Id,
                    Name = category.Name
                );
                System.enqueueJob(new NewsCategoryQueueable(nextCategory, currentPage + 1));
            } else {
                updatedCategory.Last_Synced__c = Datetime.now();
                updatedCategory.Sync__c = false;
                updatedCategory.Pages__c = currentPage;
                update updatedCategory;
            }
        } catch (Exception e) {
            System.debug(
                LoggingLevel.ERROR,
                'NewsCategoryQueueable failed for News_Category__c ' +
                    category.Id +
                    ' page ' +
                    currentPage +
                    ': ' +
                    e.getMessage() +
                    '\n' +
                    e.getStackTraceString()
            );
            updatedCategory.Sync__c = false;
            update updatedCategory;
        }
    }

    /**
     * Whether another page should be requested after this one (respects {@link #MAX_PAGES}).
     */
    private Boolean shouldEnqueueNextPage(NewsAPIResponse response) {
        if (currentPage >= MAX_PAGES) {
            return false;
        }
        if (response == null || response.articles == null || response.articles.isEmpty()) {
            return false;
        }
        if (response.articles.size() < API_PAGE_SIZE) {
            return false;
        }
        if (response.totalResults != null && currentPage * API_PAGE_SIZE >= response.totalResults) {
            return false;
        }
        return true;
    }
}

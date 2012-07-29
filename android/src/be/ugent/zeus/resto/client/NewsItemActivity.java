
package be.ugent.zeus.resto.client;

import com.actionbarsherlock.app.SherlockActivity;

import android.os.Bundle;
import android.text.Html;
import android.text.method.LinkMovementMethod;
import android.text.util.Linkify;
import android.widget.TextView;
import be.ugent.zeus.resto.client.data.NewsItem;

/**
 *
 * @author blackskad
 */
public class NewsItemActivity extends SherlockActivity {

  /** Called when the activity is first created. */
  @Override
  public void onCreate(Bundle icicle) {
    super.onCreate(icicle);
    
    setTitle(R.string.title_news);
    setContentView(R.layout.news_item);

    NewsItem item = (NewsItem) getIntent().getSerializableExtra("item");

    TextView title = (TextView) findViewById(R.id.news_item_title);
    title.setText(item.title);
    
    TextView content = (TextView) findViewById(R.id.news_item_content);
    content.setText(Html.fromHtml(item.description.replace("\n", "<br>")));
    content.setMovementMethod(LinkMovementMethod.getInstance());
    Linkify.addLinks(content, Linkify.ALL);
  }
}

# Herdr Slack Notify

HerdrプラグインからSlack Incoming Webhookへ通知します。エージェントの処理完了時、または入力・確認が必要になったときに通知します。

## 通知される状態

`pane.agent_status_changed` イベントを受け取り、次の状態で通知します。

| 状態 | Slack通知 |
| --- | --- |
| `done`、`idle`（先行する `working` 状態がある場合） | ✅ 完了 |
| `blocked` | ⚠️ ブロック |
| その他 | 通知しない |

通知にはエージェント名、タイトル（設定されている場合）、ワークスペースID、ペインIDが含まれます。
起動直後の `idle`／`done` は通知せず、同じペインで `working` になった後の完了だけを通知します。

## 必要なもの

- Herdr 0.9.1以降
- Linux
- `bash`、`jq`、`curl`、`flock`
- Slack Incoming Webhook URL

## セットアップ

1. SlackでIncoming Webhookを作成し、通知先チャンネルのWebhook URLを取得します。
2. Herdrを起動する環境に `SLACK_WEBHOOK_URL` を設定します。

   ```bash
   export SLACK_WEBHOOK_URL='https://hooks.slack.com/services/...'
   ```

   Herdrのプロセスから環境変数が見えるように、Herdrを起動するシェルやサービスの環境に設定してください。Webhook URLは秘密情報として扱い、共有リポジトリに書き込まないでください。

3. このディレクトリをプラグインとしてリンクします。

   ```bash
   herdr plugin link /path/to/herdr-slack-notify
   ```

## 動作

`SLACK_WEBHOOK_URL` が未設定の場合は通知せず、正常終了します。`done` と `idle` は、同じペインで先に `working` が記録されている場合のみ完了通知になります。`blocked` はブロック通知になります。状態の記録には `HERDR_PLUGIN_STATE_DIR` を使用します。通知対象外の状態やイベント情報がない場合も、Slackへの送信は行いません。

通知に失敗した場合は `curl` のエラーがプラグインログに記録されます。ログは次のコマンドで確認できます。

```bash
herdr plugin log list
```

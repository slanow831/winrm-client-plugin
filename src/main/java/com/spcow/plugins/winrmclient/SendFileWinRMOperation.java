package com.spcow.plugins.winrmclient;

import hudson.Extension;
import hudson.FilePath;
import hudson.Launcher;
import hudson.model.Run;
import hudson.model.TaskListener;
import hudson.tasks.CommandInterpreter;
import org.jenkinsci.Symbol;
import org.kohsuke.stapler.DataBoundConstructor;

import javax.xml.transform.stream.StreamSource;
import java.io.IOException;
import java.io.Serializable;

public class SendFileWinRMOperation extends WinRMOperation implements Serializable {

    private final String source;
    private final String destination;
    private final String ttl;
    private final static String SEND_FILE_PATH = "/com/spcow/plugins/winrmclient/SendFileWinRMOperation/Send-File.ps1";
    private final String temppath;

    @DataBoundConstructor
    public SendFileWinRMOperation(String source, String destination, String ttl, String temppath) {
        this.source = source;
        this.destination = destination;
        this.ttl = ttl;
        this.temppath = temppath;
    }

    public String getSource() {
        return source;
    }

    public String getDestination() {
        return destination;
    }

    public String getttl() {
        return ttl;
    }

    public String gettemppath() {
        return temppath;
    }

    public boolean runOperation(Run<?, ?> run, FilePath buildWorkspace, Launcher launcher, TaskListener listener,
                                String hostName, String userName, String password) {
        boolean result = false;
        try {
            StreamSource ssSendFileCommand = new StreamSource(WinRMClientBuilder.class.getResourceAsStream(SEND_FILE_PATH));
            final String strRemoteSendFile = Utils.getStringFromInputStream(ssSendFileCommand.getInputStream());
            CommandInterpreter ciSendFile = new CommandInterpreter(strRemoteSendFile) {
                @Override
                public String[] buildCommandLine(FilePath filePath) {
                    return new String[0];
                }

                @Override
                protected String getContents() {
                    return strRemoteSendFile;
                }

                @Override
                protected String getFileExtension() {
                    return Utils.getFileExtension();
                }
            };
            FilePath fpRemoteSendFile = ciSendFile.createScriptFile(buildWorkspace);
            StringBuilder sb = new StringBuilder();
            sb.append(". " + fpRemoteSendFile.getRemote());
            sb.append(System.lineSeparator());
            sb.append("Send-File");
            sb.append(" ");
            sb.append("\"" + source + "\"");
            sb.append(" ");
            sb.append("\"" + destination + "\"");
            sb.append(" ");
            sb.append("\"" + hostName + "\"");
            sb.append(" ");
            sb.append("\"" + userName + "\"");
            sb.append(" ");
            sb.append("\"" + password + "\"");
            if (ttl != null) {
                sb.append(" ");
                sb.append("\"" + ttl + "\"");
            }
            if (temppath != null) {
                sb.append(" ");
                sb.append("\"" + temppath + "\"");
            }
            CommandInterpreter remoteCommandInterpreter = new CommandInterpreter(sb.toString()) {
                @Override
                public String[] buildCommandLine(FilePath script) {
                    return Utils.buildCommandLine(script);
                }

                @Override
                protected String getContents() {
                    return Utils.getContents(command);
                }

                @Override
                protected String getFileExtension() {
                    return Utils.getFileExtension();
                }

            };
            FilePath scriptFile = remoteCommandInterpreter.createScriptFile(buildWorkspace);
            int exitStatus = launcher.launch().cmds(remoteCommandInterpreter.buildCommandLine(scriptFile)).stdout(listener).join();
            scriptFile.delete();
            fpRemoteSendFile.delete();
            result = didErrorsOccur(exitStatus);

        } catch (RuntimeException  e) {
            listener.fatalError(e.getMessage());
        } catch (InterruptedException e) {
            listener.fatalError(e.getMessage());
        } catch (IOException e) {
            listener.fatalError(e.getMessage());
        }
        return result;
    }

    private boolean didErrorsOccur(int exitStatus) {
        boolean result = true;
        if (exitStatus != 0) {
            result = false;
        }
        return result;
    }

    @Extension
    @Symbol("sendFile")
    public static class DescriptorImpl extends WinRMOperationDescriptor {
        public String getDisplayName() {
            return "Send-File";
        }

    }
}

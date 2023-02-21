package edu.uf.karoo_collab.module.pheartrate;

import edu.uf.karoo_collab.MainActivity;

import androidx.annotation.NonNull;

import java.util.Map;

import io.hammerhead.sdk.v0.SdkContext;
import io.hammerhead.sdk.v0.datatype.Dependency;
import io.hammerhead.sdk.v0.datatype.transformer.SdkTransformer;

public class PartnerHeartRateTransformer extends SdkTransformer {
    public PartnerHeartRateTransformer(@NonNull SdkContext context) {
        super(context);
    }

    @Override
    public double onDependencyChange(long l, @NonNull Map<Dependency, Double> map) {
   
        return MainActivity.getHR();
        //return Math.random() * (200 - 70 + 1) + 70;
    }
}

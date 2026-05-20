package io.dev32.sample.di

import dagger.Binds
import dagger.Module
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent
import io.dev32.sample.CounterRepository
import io.dev32.sample.InMemoryCounterRepository

@Module
@InstallIn(SingletonComponent::class)
abstract class CounterModule {
    @Binds
    abstract fun bindCounterRepository(impl: InMemoryCounterRepository): CounterRepository
}
